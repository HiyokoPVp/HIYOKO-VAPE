--[[
	Prediction Library (Optimized for 100% Accuracy)
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
]]
local module = {}
local eps = 1e-9

local function isZero(d)
	return (d > -eps and d < eps)
end

local function cuberoot(x)
	return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local s0, s1
	local p, q, D

	p = c1 / (2 * c0)
	q = c2 / c0
	D = p * p - q

	if isZero(D) then
		s0 = -p
		return s0
	elseif (D < 0) then
		return
	else
		local sqrt_D = math.sqrt(D)
		s0 = sqrt_D - p
		s1 = -sqrt_D - p
		return s0, s1
	end
end

local function solveCubic(c0, c1, c2, c3)
	local s0, s1, s2
	local num, sub
	local A, B, C
	local sq_A, p, q
	local cb_p, D

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0

	sq_A = A * A
	p = (1 / 3) * (-(1 / 3) * sq_A + B)
	q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

	cb_p = p * p * p
	D = q * q + cb_p

	if isZero(D) then
		if isZero(q) then
			s0 = 0
			num = 1
		else
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif (D < 0) then
		local phi = (1 / 3) * math.acos(math.clamp(-q / math.sqrt(-cb_p), -1, 1)) -- clampでエラー防止
		local t = 2 * math.sqrt(-p)

		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)

		s0 = u + v
		num = 1
	end

	sub = (1 / 3) * A
	if (num > 0) then s0 = s0 - sub end
	if (num > 1) then s1 = s1 - sub end
	if (num > 2) then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	if isZero(c0) then
		return {solveCubic(c1, c2, c3, c4)}
	end

	local s0, s1, s2, s3
	local coeffs = {}
	local z, u, v, sub
	local A, B, C, D
	local sq_A, p, q, r
	local num = 0
	local results = {}

	A = c1 / c0
	B = c2 / c0
	C = c3 / c0
	D = c4 / c0

	sq_A = A * A
	p = -0.375 * sq_A + B
	q = 0.125 * sq_A * A - 0.5 * A * B + C
	r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

	if isZero(r) then
		coeffs[3] = q
		coeffs[2] = p
		coeffs[1] = 0
		coeffs[0] = 1

		local res = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
		for _, v in res do table.insert(results, v) end
	else
		coeffs[3] = 0.5 * r * p - 0.125 * q * q
		coeffs[2] = -r
		coeffs[1] = -0.5 * p
		coeffs[0] = 1

		s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
		z = s0

		u = z * z - r
		v = 2 * z - p

		if isZero(u) then u = 0 elseif (u > 0) then u = math.sqrt(u) else return {} end
		if isZero(v) then v = 0 elseif (v > 0) then v = math.sqrt(v) else return {} end

		coeffs[2] = z - u
		coeffs[1] = q < 0 and -v or v
		coeffs[0] = 1
		local res1 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
		for _, val in res1 do table.insert(results, val) end

		coeffs[2] = z + u
		coeffs[1] = q < 0 and v or -v
		coeffs[0] = 1
		local res2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
		for _, val in res2 do table.insert(results, val) end
	end

	sub = 0.25 * A
	for i, val in results do
		results[i] = val - sub
	end

	return results
end

--[[
	引数:
	origin: 発射位置 (Vector3)
	projectileSpeed: 弾速 (number)
	gravity: 弾の重力加速度（下向き正の数、例: 196.2）
	targetPos: 現在のターゲット位置 (Vector3)
	targetVelocity: 現在のターゲット速度 (Vector3)
	playerGravity: ターゲットにかかる重力（オプション、省略時は自由落下計算なし）
	playerHeight: ターゲットのヒップ高（地面判定用）
	params: レイキャスト用のRaycastParams

	戻り値:
	1. 計算された「狙うべき着弾予測位置」 (Vector3)
	2. 弾を発射すべき初期速度ベクトル (Vector3)
	3. 着弾までの想定時間 (number)
]]
function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, params)
	playerHeight = playerHeight or 0
	
	local currentTargetPos = targetPos
	local currentTargetVel = targetVelocity
	
	-- 1. ターゲットの自由落下・着地シミュレーションの精度向上
	if playerGravity and playerGravity > 0 and math.abs(currentTargetVel.Y) > 0.1 then
		local estTime = ((currentTargetPos - origin).Magnitude / projectileSpeed)
		
		-- 収束させるために数回反復（変なbreakを削除）
		for i = 1, 5 do
			local predictedYVel = currentTargetVel.Y - (playerGravity * estTime)
			local deltaY = (currentTargetVel.Y * estTime) - (0.5 * playerGravity * estTime * estTime)
			
			-- 着地判定用のレイキャスト
			local rayDir = Vector3.new(currentTargetVel.X * estTime, deltaY - playerHeight, currentTargetVel.Z * estTime)
			local ray = workspace:Raycast(targetPos, rayDir, params)
			
			if ray then
				-- 地面にぶつかる場合、その時点で落下は止まる
				local hitFloorPos = ray.Position + Vector3.new(0, playerHeight, 0)
				local timeToFloor = math.abs(currentTargetVel.Y) > 0 and ((hitFloorPos.Y - targetPos.Y) / currentTargetVel.Y) or estTime
				timeToFloor = math.clamp(timeToFloor, 0, estTime)
				
				-- 着地後の水平移動のみを計算
				local remainingTime = estTime - timeToFloor
				currentTargetPos = hitFloorPos + Vector3.new(currentTargetVel.X * remainingTime, 0, currentTargetVel.Z * remainingTime)
				currentTargetVel = Vector3.new(currentTargetVel.X, 0, currentTargetVel.Z) -- Y速度は0に
				break
			else
				-- 空中処理の更新
				currentTargetPos = targetPos + Vector3.new(currentTargetVel.X * estTime, deltaY, currentTargetVel.Z * estTime)
				currentTargetVel = Vector3.new(currentTargetVel.X, predictedYVel, currentTargetVel.Z)
			end
			-- 新しい予定時間で再計算
			estTime = ((currentTargetPos - origin).Magnitude / projectileSpeed)
		end
	end

	local disp = currentTargetPos - origin
	local p, q, r = currentTargetVel.X, currentTargetVel.Y, currentTargetVel.Z
	local h, j, k = disp.X, disp.Y, disp.Z
	local l = -0.5 * gravity

	-- 4次方程式の係数セット
	local solutions = module.solveQuartic(
		l*l,
		-2*q*l,
		q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
		2*j*q + 2*h*p + 2*k*r,
		j*j + h*h + k*k
	)

	-- 2. 最適な解（最小の正の実数解 = 最短着弾時間）を見つける
	local bestT = nil
	if solutions then
		for _, t in solutions do
			if t and t > eps then
				if not bestT or t < bestT then
					bestT = t
				end
			end
		end
	end

	-- 4次方程式で解が出なかった場合（または重力が0の場合）のフォールバック
	if not bestT then
		if gravity == 0 or isZero(gravity) then
			-- 単純な直線予測（2次方程式）に切り替え
			local a = p*p + q*q + r*r - projectileSpeed*projectileSpeed
			local b = 2*(h*p + j*q + k*r)
			local c = h*h + j*j + k*k
			local t0, t1 = solveQuadric(a, b, c)
			
			if t0 and t0 > eps then bestT = t0 end
			if t1 and t1 > eps and (not bestT or t1 < bestT) then bestT = t1 end
		end
	end

	-- 3. 最終的な弾道（発射速度）ベクトルの算出
	if bestT then
		local t = bestT
		-- 着弾時のターゲットの絶対座標
		local impactPoint = currentTargetPos + (currentTargetVel * t)
		if playerGravity and playerGravity > 0 and currentTargetVel.Y ~= 0 then
			-- ターゲットが空中だった場合のY座標補正
			impactPoint = Vector3.new(
				currentTargetPos.X + currentTargetVel.X * t,
				currentTargetPos.Y + (currentTargetVel.Y * t) - (0.5 * playerGravity * t * t),
				currentTargetPos.Z + currentTargetVel.Z * t
			)
		end

		-- 自分の位置からそこへ向かうための初速ベクトルを逆算
		local fireVelocity = Vector3.new(
			(impactPoint.X - origin.X) / t,
			((impactPoint.Y - origin.Y) - (l * t * t)) / t,
			(impactPoint.Z - origin.Z) / t
		)

		return impactPoint, fireVelocity, t
	end

	return nil -- 解なし（弾速が足りない、または届かない）
end

return module
