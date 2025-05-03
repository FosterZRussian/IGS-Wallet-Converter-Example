-- IGS (https://gm-donate.net) 
-- Пример автоматического конвертера баланса в игровую валюту по игровым наборам/пакетам.

-- Пример конфига для игровых наборов
UI = {}
UI.ShopDonatePackages = {}
local function add_price(price, reward)
	table.insert(UI.ShopDonatePackages,  { reward = reward, price = price } )
end

add_price(78, 78)
add_price(145, 145)
add_price(399, 450)
add_price(750, 900)
add_price(1450, 1800)
add_price(3900, 5000)
add_price(9750, 13500)

UI.ShopDonatePackagesReversed = {}
local DonatePackagesCount = #UI.ShopDonatePackages
for i = 1, DonatePackagesCount do
	UI.ShopDonatePackagesReversed[ (DonatePackagesCount-i) + 1 ] = UI.ShopDonatePackages[i]
end


local AlreadyChecking = {}

-- Наша функция для проверки игрока (можем вызывать в момент пополнения баланса/авторизации на игровом сервере)
function IGS_CheckCredits(ply)
	local s64 = ply:SteamID64()
		
	local p_id = ply.p_id
	if !p_id then return end

	-- Предотвращаем просчет игрока если его баланс уже считается
	if AlreadyChecking[s64] then return end
	AlreadyChecking[s64] = true

	-- Получаем баланс игрока
	IGS.GetBalance(s64, function(real_balance)
		real_balance = real_balance or 0

		-- Не считаем игрока если у него нулевой баланс
		if real_balance == 0 then 
			AlreadyChecking[s64] = false
			return 
		end
		
		local give_game_wallet = 0		
		local balance_left = real_balance

		-- Определяем сколько баланса можно сконвертировать по игровым наборам
		print('Calcing packages:')
		for k,v in ipairs(UI.ShopDonatePackagesReversed) do -- Бегаем от самого высокого игрового набора, до самого низкого, чтобы сконвертировать на выгодных условиях
			if balance_left < v.price then continue end

			-- Определяем, сколько "таких" игровых наборов игрок может получить за текущий баланс
			local give_packages_count = math.floor(balance_left / v.price)
			if give_packages_count == 0 then continue end

			local take_balance_by_packages = give_packages_count * v.price
			local give_game_wallet_by_packages = (give_packages_count * v.reward)
				
			print('\t Take balance', take_balance_by_packages)
			print("\t\t Give wallet", give_game_wallet_by_packages)
			
			give_game_wallet = give_game_wallet + give_game_wallet_by_packages
			balance_left = balance_left - take_balance_by_packages
		end
		

    
		local final_exchange_rate = 0.5
		local final_exchange_reward = 1
		-- Определяем сколько финального баланса можно сконвертировать по курсу 0.5 (баланса) к 1 (игровых монет)		
		local final_convert_count = math.floor(balance_left / final_exchange_rate)

    -- Пытаемся сконвертировать оставшуюся валюту
		if final_convert_count > 0 then
			print('Calcing final convert:')
			local take_balance_by_final_convert = final_convert_count * final_exchange_rate -- Сколько забираем (0.5 баланса)
			local give_wallet_by_final_convert = final_convert_count * final_exchange_reward -- Сколько даем (для примера 1 игровая монета за каждые 0.5 баланса)

			print("\t Take balance", take_balance_by_final_convert)		
			print("\t\t Give wallet", give_wallet_by_final_convert)
			
			give_game_wallet = give_game_wallet + give_wallet_by_final_convert
			balance_left = balance_left - take_balance_by_final_convert
		end
		

		print("----------")
		
		print("Real balance", real_balance)
		local take_balance = real_balance-balance_left		
		print("Left balance (potential)", balance_left) -- Принт для проверки, чтобы убедиться что наши копейки не сконвертировались в пустоту


		
		-- Отнимаем просчитанный баланс
		IGS.Transaction(s64, -take_balance, "Конвертация " .. take_balance .. " руб.  в игровую валюту", function(trans_id)			
			print("Take balance", take_balance)		
			
			-- Выдаем нашу игровую валюту
			svdb.players.GiveWallet(p_id, "p_crd", give_game_wallet, function() -- (используйте вашу функцию)			
				print("Give wallet", give_game_wallet)
				
				-- Делаем лог в IGS, на случай если у нас что-то где-то сломается и нужны будут логи об "успешности"
				IGS.Transaction(s64, 0, "Успешно выдано " .. give_game_wallet .. " игровой валюты [#" .. trans_id .. "]")
				-- Тут же желательно сделать лог  уже в нашу БД.				

				-- Отправляем уведомление игроку 
				if IsValid(ply) then
					ply:ShowMsg("Зачислено " .. give_game_wallet .. " кредитов.") -- (используйте вашу функцию)
				end
				
				-- Успешно посчитали игрока, разрешаем следующие просчеты
				AlreadyChecking[s64] = false 
			end)
		end)

	end)
end


hook.Add("IGS.PaymentStatusUpdated", "GM-Donate.ThanksForDonate", function(pl, tbl)
	IGS_CheckCredits(pl)
end)
