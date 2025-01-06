script_name("ArzToolKit")
script_author("Dawlat")
script_version("v1.0.0")

require 'lib.moonloader'
local se = require "samp.events"
local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
local inicfg = require 'inicfg'
local hotkey = require 'mimhotkey'

-- ######## General ########
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local version = "v1.0"
local scriptName = "ArzToolKit " .. version .. " by Dawlat"
local configFileName = "arztoolkit_config"
local configFile
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local sizeX, sizeY = getScreenResolution()
local lastActivityTime = os.time()
local playerName
local authTime
local famTaxesSum
local lastMouseX, lastMouseY
local isAuth = false
local isTaxesPaid = false
local isFamTaxesPaid = false
local isAfk = false
hotkey.no_flood = false

local config = {
    settings = {
        fstGuard = false,
        secGuard = false,
        trdGuard = false,
        fthGuard = false,
        splitVRcmds = false,
        autoAdDetect = false,
        addPhoneNumber = false,
        adAntiFlood = false,
        autoAd = false,
        autoTaxes = false,
        autoFamTaxes = false,
        guardActionDelay = 150,
        taxesActionDelay = 150,
        autoTaxesDelay = 60,
        autoFamTaxesDelay = 65,
        autoAdPeriod = 180,
        autoAdAfk = 180,
        adCoolDown = 180,
        autoAdText = u8 "Здесь могла бы быть ваша реклама",
        phoneNumber = u8 "",
        keywords = u8 "продам,куплю,обменяю,сдам в аренду,возьму в аренду",
    },
    hotkey = {
        fstGuardKey = "[53]",
        secGuardKey = "[54]",
        trdGuardKey = "[55]",
        fthGuardKey = "[56]",
        fstGuardInvent = "[49]",
        secGuardInvent = "[50]",
        trdGuardInvent = "[51]",
        fthGuardInvent = "[52]",
    }
}

-- ######## Setting menu ########
local tab = 1
local showSettings = imgui.new.bool(false)
local settingFlags = imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoCollapse
local keywords
local splitVRcmds
local autoAdDetect
local adAntiFlood
local adCoolDown
local addPhoneNumber
local phoneNumber
local autoAd
local autoAdActive
local autoAdText
local autoAdPeriod
local autoAdAfk
local lastAutoAd = 0
local lastAdTime = 0
local autoTaxes
local autoFamTaxes
local autoTaxesDelay
local autoFamTaxesDelay
local guardActionDelay
local fstGuard
local secGuard
local trdGuard
local fthGuard
local bind


function main()
    -- ######## On start ########
    repeat wait(100) until isSampAvailable()

    local isPlayerId, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    playerName = sampGetPlayerNickname(playerId)

    configFile = inicfg.load(config, configFileName)
    splitVRcmds = imgui.new.bool(configFile.settings.splitVRcmds)
    autoAdDetect = imgui.new.bool(configFile.settings.autoAdDetect)
    addPhoneNumber = imgui.new.bool(configFile.settings.addPhoneNumber)
    adAntiFlood = imgui.new.bool(configFile.settings.adAntiFlood)
    autoAd = imgui.new.bool(configFile.settings.autoAd)
    autoTaxes = imgui.new.bool(configFile.settings.autoTaxes)
    autoFamTaxes = imgui.new.bool(configFile.settings.autoFamTaxes)
    fstGuard = imgui.new.bool(configFile.settings.fstGuard)
    secGuard = imgui.new.bool(configFile.settings.secGuard)
    trdGuard = imgui.new.bool(configFile.settings.trdGuard)
    fthGuard = imgui.new.bool(configFile.settings.fthGuard)
    keywords = new.char[256](configFile.settings.keywords)
    phoneNumber = new.char[256](configFile.settings.phoneNumber)
    autoAdText = new.char[256](configFile.settings.autoAdText)
    adCoolDown = new.char[256](numberToBuffer(configFile.settings.adCoolDown))
    autoAdPeriod = new.char[256](numberToBuffer(configFile.settings.autoAdPeriod))
    autoAdAfk = new.char[256](numberToBuffer(configFile.settings.autoAdAfk))
    autoTaxesDelay = new.char[256](numberToBuffer(configFile.settings.autoTaxesDelay))
    autoFamTaxesDelay = new.char[256](numberToBuffer(configFile.settings.autoFamTaxesDelay))
    guardActionDelay = new.char[256](numberToBuffer(configFile.settings.guardActionDelay))
    taxesActionDelay = new.char[256](numberToBuffer(configFile.settings.taxesActionDelay))

    chatMessage("Открыть настройки - /at")

    -- ######## Chat commands ########
    sampRegisterChatCommand("at", toggleSettingWindow)
    sampRegisterChatCommand("aa", toggleAutoAd)
    sampRegisterChatCommand("vr", sendVipChatMessage)
    sampRegisterChatCommand("vra", sendVipChatAdMessage)
    sampRegisterChatCommand("ptax", payTaxes)
    sampRegisterChatCommand("pftax", payFamTaxes)

    -- ######## HotKeys ########
    setBinds()
    hotkey.RegisterCallback('Toggle guard 1', bind.fstGuardToggle.key, bind.fstGuardToggle.callback)
    hotkey.RegisterCallback('Toggle guard 2', bind.secGuardToggle.key, bind.secGuardToggle.callback)
    hotkey.RegisterCallback('Toggle guard 3', bind.trdGuardToggle.key, bind.trdGuardToggle.callback)
    hotkey.RegisterCallback('Toggle guard 4', bind.fthGuardToggle.key, bind.fthGuardToggle.callback)
    hotkey.RegisterCallback('Open guard invent 1', bind.fstGuardInvent.key, bind.fstGuardInvent.callback)
    hotkey.RegisterCallback('Open guard invent 2', bind.secGuardInvent.key, bind.secGuardInvent.callback)
    hotkey.RegisterCallback('Open guard invent 3', bind.trdGuardInvent.key, bind.trdGuardInvent.callback)
    hotkey.RegisterCallback('Open guard invent 4', bind.fthGuardInvent.key, bind.fthGuardInvent.callback)

    -- ######## Execution every # ms ########
    while true do
        wait(1000)

        checkLastActivityTime()
        if ((os.time() - lastActivityTime) > bufferToNumber(autoAdAfk)) then
            isAfk = true
        else
            isAfk = false
        end

        if (os.difftime(os.time(), lastAutoAd) >= bufferToNumber(autoAdPeriod) and autoAdActive) then
            sendAutoAdMessage()
        end

        if (isAuth and not isTaxesPaid or isAuth and not isFamTaxesPaid) then
            if (os.difftime(os.time(), authTime) >= bufferToNumber(autoTaxesDelay) and autoTaxes[0] and not isTaxesPaid) then
                payTaxes()
                isTaxesPaid = true
            end

            if (os.difftime(os.time(), authTime) >= bufferToNumber(autoFamTaxesDelay) and autoFamTaxes[0] and not isFamTaxesPaid) then
                payFamTaxes()
                isFamTaxesPaid = true
            end
        end
    end
end

function sendVipChatMessage(message)
    if autoAdDetect then
        local isAdMessage
        local keywordsList = {}
        local keywordsStr = u8:decode(ffi.string(keywords))

        for word in keywordsStr:gmatch("[^,]+") do
            table.insert(keywordsList, word)
        end

        for _, keyword in ipairs(keywordsList) do
            if message:find(keyword) ~= nil then
                isAdMessage = true
            end
        end

        if isAdMessage then
            sendVipMessageAs(message, 1)
            return
        end
    end

    if splitVRcmds[0] then
        sendVipMessageAs(message, 0)
    else
        sampSendChat("/vr " .. message)
    end
end

function sendVipChatAdMessage(message)
    if splitVRcmds[0] then
        sendVipMessageAs(message, 1)
    else
        chatMessage("Включите в настройках разделение команд VIP-чата!")
    end
end

-- ### 0 - usual, 1 - ads
function sendVipMessageAs(message, type)
    if adAntiFlood[0] and type == 1 then
        local timeDif = os.difftime(os.time(), lastAdTime)
        local coolDown = bufferToNumber(adCoolDown) or 0
        local remainingTime = coolDown - timeDif
        if (timeDif < coolDown) then
            chatMessage(("Сообщение не отправлено, так как не прошло КД рекламы! Попробуйте через: {3ac253}%d секунд")
                :format(remainingTime))
            return
        end
    end

    if type == 1 and addPhoneNumber[0] then
        local phone = u8:decode(ffi.string(phoneNumber))
        message = message .. " " .. phone
    end

    sampSendChat("/vr " .. message)
    closeDialogWithDelay(type)
end

function sendAutoAdMessage()
    if (isAfk) then
        chatMessage("Реклама не отправлена автоматически, так как вы находитесь АФК!")
        lastAutoAd = os.time()
    else
        sendVipMessageAs(u8:decode(ffi.string(autoAdText)), 1)
        lastAutoAd = os.time()
    end
end

function closeDialogWithDelay(buttonId)
    lua_thread.create(function()
        wait(150)
        sampCloseCurrentDialogWithButton(buttonId)
    end)
end

function toggleSettingWindow()
    showSettings[0] = not showSettings[0]
end

function toggleAutoAd()
    if (autoAd[0]) then
        autoAdActive = not autoAdActive

        if (autoAdActive) then
            chatMessage(
                ("Авто-реклама активирована. Период отправки: {3ac253}%d секунд.{FFFFFF} Уход в АФК: {3ac253}%d секунд.")
                :format(bufferToNumber(autoAdPeriod), bufferToNumber(autoAdAfk))
            )
        else
            chatMessage("Авто-реклама деактивирована.")
        end
    else
        chatMessage("Сначала нужно активировать авто-рекламу в настройках!")
    end
end

function checkLastActivityTime()
    local mx, my = getCursorPos()
    if mx ~= nil and my ~= nil then
        if mx ~= lastMouseX or my ~= lastMouseY then
            lastMouseX, lastMouseY = mx, my
            lastActivityTime = os.time()
        end
    end
end

-- #################################################################
-- #==================== Автоматизация действий ===================#
-- #################################################################
function payTaxes()
    lua_thread.create(function()
        sampSendChat("/phone")
        wait(bufferToNumber(taxesActionDelay))
        sendCustomPacket('launchedApp|24')
        wait(bufferToNumber(taxesActionDelay))
        sampSendDialogResponse(6565, 1, 4, "")
        wait(bufferToNumber(taxesActionDelay))
        sampCloseCurrentDialogWithButton(1)
        sampSendChat("/phone")
    end)
end

function payFamTaxes()
    local dialogInfo

    lua_thread.create(function()
        sampSendChat("/fammenu")
        wait(bufferToNumber(taxesActionDelay))
        sampSendClickTextdraw(2073)
        wait(bufferToNumber(taxesActionDelay))

        dialogInfo = sampGetDialogText()
        if (string.find(dialogInfo, "Оплатить налог на квартиру")) then
            sampSendDialogResponse(2763, 1, 10, "")
            wait(bufferToNumber(taxesActionDelay))
            sampSendDialogResponse(15247, 1, 0, famTaxesSum)
            wait(bufferToNumber(taxesActionDelay))
        else
            chatMessage("Ошибка оплаты налога за семейную квартиру!")
        end

        sampCloseCurrentDialogWithButton(0)
        wait(bufferToNumber(taxesActionDelay))
        sampSendClickTextdraw(65535)
    end)
end

function toggleGuard(id)
    local guardDraw = { 2075, 2097, 2119, 2141 }
    local dialogInfo

    lua_thread.create(function()
        sampSendChat("/invent")
        wait(bufferToNumber(guardActionDelay))
        sampSendClickTextdraw(2116)
        wait(bufferToNumber(guardActionDelay))
        sampSendClickTextdraw(guardDraw[id])
        wait(bufferToNumber(guardActionDelay))
        dialogInfo = sampGetDialogText()
        sampSendDialogResponse(25757, 1, 0, "")

        if (string.find(dialogInfo, "Спрятать")) then
            wait(bufferToNumber(guardActionDelay))
            sampCloseCurrentDialogWithButton(1)
            wait(bufferToNumber(guardActionDelay))
            sampSendClickTextdraw(65535)
        end
    end)
end

function openGuardInvent(id)
    local guardInventDraw = { 2091, 2113, 2135, 2157 }

    lua_thread.create(function()
        sampSendChat("/invent")
        wait(bufferToNumber(guardActionDelay))
        sampSendClickTextdraw(2116)
        wait(bufferToNumber(guardActionDelay))
        sampSendClickTextdraw(guardInventDraw[id])
    end)
end

-- ################################################################################
-- #============================== USER INTERFACE ================================#
-- ################################################################################
local newFrame = imgui.OnFrame(
    function() return showSettings[0] end,
    function(player)
        imgui.SetNextWindowPos((imgui.ImVec2(sizeX / 2, sizeY / 2)), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(600, 350), imgui.Cond.Always)
        imgui.Begin(scriptName, showSettings, settingFlags)

        for numberTab, nameTab in pairs({ 'VR чат', 'Налоги', 'Охрана', 'Информация' }) do
            if imgui.Button(u8(nameTab), imgui.ImVec2(100, 30)) then
                tab = numberTab
            end
        end
        imgui.SetCursorPos(imgui.ImVec2(115, 28))
        if imgui.BeginChild('##ArzToolKit_child' .. tab, imgui.ImVec2(475, 310), true) then
            if (tab == 1) then
                -- #### Авто-реклама
                if imgui.Checkbox(u8 "Авто-реклама", autoAd) then
                    configFile.settings.autoAd = autoAd[0]
                    inicfg.save(configFile, configFileName)
                end
                -- #### Настройка авто-рекламы
                if (autoAd[0]) then
                    -- #### Текст рекламы
                    imgui.PushItemWidth(350)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoAdText", autoAdText, 256) then
                        configFile.settings.autoAdText = ffi.string(autoAdText)
                        inicfg.save(configFile, configFileName)
                    end

                    -- #### Периодичность рекламы
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoAdPeriod", autoAdPeriod, 256) then
                        configFile.settings.autoAdPeriod = bufferToNumber(autoAdPeriod)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "период отправки (секунд)")
                    imgui.PopStyleColor()

                    -- #### Распознавание АФК через % секунд
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoAdAfk", autoAdAfk, 256) then
                        configFile.settings.autoAdAfk = bufferToNumber(autoAdAfk)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "время ухода в АФК (секунд)")
                    imgui.PopStyleColor()
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Автоматически отправляет рекламу с указаным\nпериодом когда вы находитесь не АФК.\nАктивация/деактивация - /aa")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                -- #### Разделение команд VIP-чата
                if imgui.Checkbox(u8 "Разделение команд VIP-чата", splitVRcmds) then
                    configFile.settings.splitVRcmds = splitVRcmds[0]
                    inicfg.save(configFile, configFileName)
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Для отправки обычного сообщения - /vr\nДля отправки рекламного сообщения - /vra")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                -- #### Автоматическое определение рекламы
                if imgui.Checkbox(u8 "Автоматическое определение рекламы", autoAdDetect) then
                    configFile.settings.autoAdDetect = autoAdDetect[0]
                    inicfg.save(configFile, configFileName)
                end
                -- #### Буффер ключевых слов
                if (autoAdDetect[0]) then
                    imgui.PushItemWidth(350)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##keywords", keywords, 256) then
                        configFile.settings.keywords = ffi.string(keywords)
                        inicfg.save(configFile, configFileName)
                    end
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Автоматически отправляет сообщение как рекламное\nпри наличии ключевых слов в тексте")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                -- #### Добавлять номер телефона к рекламе
                if imgui.Checkbox(u8 "Добавлять номер телефона к рекламе", addPhoneNumber) then
                    configFile.settings.addPhoneNumber = addPhoneNumber[0]
                    inicfg.save(configFile, configFileName)
                end
                -- #### Настройка номера телефона
                if (addPhoneNumber[0]) then
                    imgui.PushItemWidth(200)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##phoneNumber", phoneNumber, 256) then
                        configFile.settings.phoneNumber = ffi.string(phoneNumber)
                        inicfg.save(configFile, configFileName)
                    end
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Автоматически добавляет номер телефона\nк рекламному сообщению")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                -- #### Анти-флуд рекламой
                if imgui.Checkbox(u8 "Анти-флуд рекламой", adAntiFlood) then
                    configFile.settings.adAntiFlood = adAntiFlood[0]
                    inicfg.save(configFile, configFileName)
                end
                -- #### Настройка КД рекламы
                if (adAntiFlood[0]) then
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##adCooldown", adCoolDown, 256) then
                        configFile.settings.adCoolDown = bufferToNumber(adCoolDown)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "КД рекламы (секунд)")
                    imgui.PopStyleColor()
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Не позволяет отправлять рекламное сообщение\nчаще чем в указанное кол-во секунд")
                imgui.PopStyleColor()

                -- ######## Вкладка "НАЛОГИ" ########
            elseif tab == 2 then
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Настройка задержки:")
                imgui.PopStyleColor()
                imgui.PushItemWidth(50)
                if imgui.InputText(u8 "##taxesActionDelay", taxesActionDelay, 256) then
                    configFile.settings.taxesActionDelay = bufferToNumber(taxesActionDelay)
                    inicfg.save(configFile, configFileName)
                end
                imgui.SameLine()
                imgui.Text(u8 "задержка между действиями")
                imgui.SameLine()
                imgui.TextDisabled("(?)")
                if imgui.IsItemHovered(0) then
                    imgui.BeginTooltip()
                    imgui.Text(u8 "При стабильном соединении, оптимальная задержка - 150мс.\nКорректируйте данное значение в соответствии с вашим соединением.")
                    imgui.EndTooltip()
                end


                imgui.Dummy(imgui.ImVec2(0, 3))

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Настройка оплаты налогов:")
                imgui.PopStyleColor()

                -- #### Авто-оплата налогов
                if imgui.Checkbox(u8 "Авто-оплата налогов", autoTaxes) then
                    configFile.settings.autoTaxes = autoTaxes[0]
                    inicfg.save(configFile, configFileName)
                end
                if (autoTaxes[0]) then
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoTaxesDelay", autoTaxesDelay, 256) then
                        configFile.settings.autoTaxesDelay = bufferToNumber(autoTaxesDelay)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "задержка после входа (секунд)")
                    imgui.PopStyleColor()
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Ручная активация оплаты - /ptax\nАвтоматически оплачивает все налоги при входе в игру\n(необходимо иметь возможность оплаты через телефон)")
                imgui.PopStyleColor()

                imgui.Dummy(imgui.ImVec2(0, 3))

                -- #### Авто-оплата семейных налогов
                if imgui.Checkbox(u8 "Авто-оплата семейных налогов", autoFamTaxes) then
                    configFile.settings.autoFamTaxes = autoFamTaxes[0]
                    inicfg.save(configFile, configFileName)
                end
                if (autoFamTaxes[0]) then
                    imgui.PushItemWidth(50)
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if imgui.InputText(u8 "##autoFamTaxesDelay", autoFamTaxesDelay, 256) then
                        configFile.settings.autoFamTaxesDelay = bufferToNumber(autoFamTaxesDelay)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                    imgui.Text(u8 "задержка после входа (секунд)")
                    imgui.PopStyleColor()
                end
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Ручная активация оплаты - /pftax\nАвтоматически оплачивает налоги за семейную квартиру \nпри входе в игру")
                imgui.PopStyleColor()

                -- ######## Вкладка "ОХРАНА" ########
            elseif tab == 3 then
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Настройка задержки:")
                imgui.PopStyleColor()
                imgui.PushItemWidth(50)
                if imgui.InputText(u8 "##guardActionDelay", guardActionDelay, 256) then
                    configFile.settings.guardActionDelay = bufferToNumber(guardActionDelay)
                    inicfg.save(configFile, configFileName)
                end
                imgui.SameLine()
                imgui.Text(u8 "задержка между действиями")
                imgui.SameLine()
                imgui.TextDisabled("(?)")
                if imgui.IsItemHovered(0) then
                    imgui.BeginTooltip()
                    imgui.Text(u8 "При стабильном соединении, оптимальная задержка - 150мс.\nКорректируйте данное значение в соответствии с вашим соединением.")
                    imgui.EndTooltip()
                end

                imgui.Dummy(imgui.ImVec2(0, 3))

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(160, 160, 160))
                imgui.Text(u8 "Настройка охранников:")
                imgui.PopStyleColor()
                if imgui.Checkbox(u8 "Использовать охранника #1", fstGuard) then
                    configFile.settings.fstGuard = fstGuard[0]
                    inicfg.save(configFile, configFileName)
                end
                if fstGuard[0] then
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_fstGuard = hotkey.KeyEditor('Toggle guard 1', 'Key', imgui.ImVec2(85, 25))
                    if hotkey_fstGuard then
                        configFile.hotkey.fstGuardKey = encodeJson(hotkey_fstGuard)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Призвать/спрятать охранника")

                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_fstGuardInvent = hotkey.KeyEditor('Open guard invent 1', 'Key', imgui.ImVec2(85, 25))
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if hotkey_fstGuardInvent then
                        configFile.hotkey.fstGuardInvent = encodeJson(hotkey_fstGuardInvent)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Открыть инвентарь охранника")
                end

                if imgui.Checkbox(u8 "Использовать охранника #2", secGuard) then
                    configFile.settings.secGuard = secGuard[0]
                    inicfg.save(configFile, configFileName)
                end
                if secGuard[0] then
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_secGuard = hotkey.KeyEditor('Toggle guard 2', 'Key', imgui.ImVec2(85, 25))
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if hotkey_secGuard then
                        configFile.hotkey.secGuardKey = encodeJson(hotkey_secGuard)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Призвать/спрятать охранника")

                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_secGuardInvent = hotkey.KeyEditor('Open guard invent 2', 'Key', imgui.ImVec2(85, 25))
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if hotkey_secGuardInvent then
                        configFile.hotkey.secGuardInvent = encodeJson(hotkey_secGuardInvent)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Открыть инвентарь охранника")
                end

                if imgui.Checkbox(u8 "Использовать охранника #3", trdGuard) then
                    configFile.settings.trdGuard = trdGuard[0]
                    inicfg.save(configFile, configFileName)
                end
                if trdGuard[0] then
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_trdGuard = hotkey.KeyEditor('Toggle guard 3', 'Key', imgui.ImVec2(85, 25))
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if hotkey_trdGuard then
                        configFile.hotkey.trdGuardKey = encodeJson(hotkey_trdGuard)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Призвать/спрятать охранника")

                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_trdGuardInvent = hotkey.KeyEditor('Open guard invent 3', 'Key', imgui.ImVec2(85, 25))
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if hotkey_trdGuardInvent then
                        configFile.hotkey.trdGuardInvent = encodeJson(hotkey_trdGuardInvent)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Открыть инвентарь охранника")
                end

                if imgui.Checkbox(u8 "Использовать охранника #4", fthGuard) then
                    configFile.settings.fthGuard = fthGuard[0]
                    inicfg.save(configFile, configFileName)
                end
                if fthGuard[0] then
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_fthGuard = hotkey.KeyEditor('Toggle guard 4', 'Key', imgui.ImVec2(85, 25))
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if hotkey_fthGuard then
                        configFile.hotkey.fthGuardKey = encodeJson(hotkey_fthGuard)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Призвать/спрятать охранника")

                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    local hotkey_fthGuardInvent = hotkey.KeyEditor('Open guard invent 4', 'Key', imgui.ImVec2(85, 25))
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + 30)
                    if hotkey_fthGuardInvent then
                        configFile.hotkey.fthGuardInvent = encodeJson(hotkey_fthGuardInvent)
                        inicfg.save(configFile, configFileName)
                    end
                    imgui.SameLine()
                    imgui.Text(u8 "Открыть инвентарь охранника")
                end

                -- ######## Вкладка "ИНФОРМАЦИЯ" ########
            elseif tab == 4 then
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 'Автор скрипта:')
                imgui.SameLine()
                imgui.PopStyleColor()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 'Dawlat_Montgomery')
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 'Сервер:')
                imgui.SameLine()
                imgui.PopStyleColor()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 'Scottdale[03]')
                imgui.PopStyleColor()

                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 158, 0))
                imgui.Text(u8 'Связь:')
                imgui.SameLine()
                imgui.PopStyleColor()
                imgui.PushStyleColor(imgui.Col.Text, toRGBVec(255, 255, 255))
                imgui.Text(u8 'Telegram @oblivionGM')
                imgui.PopStyleColor()
            end
            imgui.EndChild()
        end
        imgui.End()
    end
)

-- #################################################################################
-- #============================== Обработка событий ==============================#
-- #################################################################################
function se.onServerMessage(color, text)
    if text:find("Добро пожаловать на Arizona Role Play!") and color == -10270721 then
        isAuth = true
        authTime = os.time()
    end

    if text:find("%[VIP ADV%] {FFFFFF}" .. tostring(playerName) .. "%[%d+%]:") then
        lastAdTime = os.time()
    end
end

function se.onShowDialog(dialogId, style, title, button1, button2, text)
    -- Диалог с вводом суммы оплаты за семейную квартиру
    if (dialogId == 15247) then
        famTaxesSum = string.match(text, "{ffff00}$(%d+)")
    end

    if title:match("Призыв охранника") then
        lua_thread.create(function()
            wait(200)
            sampCloseCurrentDialogWithButton(0)
        end)
    end
end

-- #################################################################################
-- #============================ Работа с RPC пакетами ============================#
-- #################################################################################
function onReceivePacket(id, bs)
    local text, ids = bitStreamToString(bs)
end

function bitStreamToString(bs)
    local arr, t = {}, {}
    for i = 1, raknetBitStreamGetNumberOfBytesUsed(bs) do
        table.insert(arr, raknetBitStreamReadInt8(bs))
    end
    for k, v in ipairs(arr) do
        if v >= 32 and v <= 255 then
            table.insert(t, string.char(v))
        end
    end
    return table.concat(t, ''), table.concat(arr, ', ')
end

function sendCustomPacket(text)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt32(bs, #text)
    raknetBitStreamWriteString(bs, text)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

-- #######################################################################################
-- #============================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==============================#
-- #######################################################################################
function isInArray(value, array)
    for _, element in ipairs(array) do
        if element == value then
            return true
        end
    end

    return false
end

function bufferToNumber(buffer)
    local strValue = ffi.string(buffer)
    strValue = strValue:gsub("[^%d]", "")

    return tonumber(strValue) or 0
end

function numberToBuffer(num)
    local strValue = tostring(num)
    return new.char[256](strValue)
end

function toRGBVec(r, g, b)
    return imgui.ImVec4(r / 255, g / 255, b / 255, 1);
end

function chatMessage(message, ...)
    message = ("[" .. scriptName .. "]" .. "{EEEEEE} " .. message)
    return sampAddChatMessage(message, 0xFFF2812D)
end

-- #################################################################
-- #============================ СТИЛИ ============================#
-- #################################################################
imgui.OnInitialize(function()
    imgui.Theme()
end)

function imgui.Theme()
    imgui.SwitchContext()
    -- ####### Style #######
    imgui.GetStyle().FramePadding                            = imgui.ImVec2(5, 5)
    imgui.GetStyle().TouchExtraPadding                       = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing                           = 0
    imgui.GetStyle().ScrollbarSize                           = 10
    imgui.GetStyle().GrabMinSize                             = 10

    -- ####### Border #######
    imgui.GetStyle().WindowBorderSize                        = 1
    imgui.GetStyle().ChildBorderSize                         = 1
    imgui.GetStyle().PopupBorderSize                         = 1
    imgui.GetStyle().FrameBorderSize                         = 1
    imgui.GetStyle().TabBorderSize                           = 1

    -- ####### Rounding #######
    imgui.GetStyle().WindowRounding                          = 5
    imgui.GetStyle().ChildRounding                           = 5
    imgui.GetStyle().FrameRounding                           = 5
    imgui.GetStyle().PopupRounding                           = 5
    imgui.GetStyle().ScrollbarRounding                       = 5
    imgui.GetStyle().GrabRounding                            = 5
    imgui.GetStyle().TabRounding                             = 5

    -- ####### Align #######
    imgui.GetStyle().WindowTitleAlign                        = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign                         = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign                     = imgui.ImVec2(0.5, 0.5)

    -- ####### Colors #######
    imgui.GetStyle().Colors[imgui.Col.Text]                  = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]          = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]              = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                = imgui.ImVec4(0.25, 0.25, 0.25, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]          = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]               = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]        = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]         = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]               = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]         = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]      = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]             = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]           = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]         = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]  = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]   = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]             = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]            = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]      = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]         = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]         = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]          = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]             = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]      = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]            = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]     = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                   = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]            = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]             = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]          = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]    = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]             = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]      = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]         = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]  = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]        = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]        = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]          = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]     = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]      = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end

-- #################################################################
-- #============================ Бинды ============================#
-- #################################################################
function setBinds()
    bind = {
        -- ## Toggle guard
        fstGuardToggle = {
            key = decodeJson(configFile.hotkey.fstGuardKey),
            callback = function()
                if (fstGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    toggleGuard(1)
                end
            end
        },
        secGuardToggle = {
            key = decodeJson(configFile.hotkey.secGuardKey),
            callback = function()
                if (secGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    toggleGuard(2)
                end
            end
        },
        trdGuardToggle = {
            key = decodeJson(configFile.hotkey.trdGuardKey),
            callback = function()
                if (trdGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    toggleGuard(3)
                end
            end
        },
        fthGuardToggle = {
            key = decodeJson(configFile.hotkey.fthGuardKey),
            callback = function()
                if (fthGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    toggleGuard(4)
                end
            end
        },

        -- ## Open guard's invent
        fstGuardInvent = {
            key = decodeJson(configFile.hotkey.fstGuardInvent),
            callback = function()
                if (fstGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    openGuardInvent(1)
                end
            end
        },
        secGuardInvent = {
            key = decodeJson(configFile.hotkey.secGuardInvent),
            callback = function()
                if (secGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    openGuardInvent(2)
                end
            end
        },
        trdGuardInvent = {
            key = decodeJson(configFile.hotkey.trdGuardInvent),
            callback = function()
                if (trdGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    openGuardInvent(3)
                end
            end
        },
        fthGuardInvent = {
            key = decodeJson(configFile.hotkey.fthGuardInvent),
            callback = function()
                if (fthGuard[0] and not sampIsChatInputActive() and not sampIsDialogActive()) then
                    openGuardInvent(4)
                end
            end
        },
    }
end
