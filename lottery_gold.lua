--[[
DELETE FROM acore_world.game_event WHERE eventEntry = 200;

INSERT INTO acore_world.game_event 
(eventEntry, start_time, end_time, occurence, `length`, holiday, holidayStage, description, world_event, announce) 
VALUES
(200, '2025-01-04 18:00:00', '2030-12-31 23:59:59', 10080, 10080, 0, 0, 'Weekly Lottery Drawing', 0, 2);

 ]]
local npcId = 777000

local lottery_tickets = {}

-- local GOSSIP_ACTION_INFO_DEF = 1000
-- local GOSSIP_SENDER_MAIN = 1

local menuId = 0x7FFFFFFF
-----------------------------------------------------
-- Events
local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_LOGOUT = 4
local GAME_EVENT_START = 34
local GAME_EVENT_STOP = 35

local GOSSIP_EVENT_ON_HELLO = 1
local GOSSIP_EVENT_ON_SELECT = 2
-----------------------------------------------------
--color picker function :D
local function SetColor(colorId, text)
    return "|c" .. colorId .. text .. "|r"
end

-- player:GossipMenuAddItem(0, SetColor("FF7D2DBE", "Buy a ticket"), 0, 1) example of how to use SetColor function to change the color of the text
-----------------------------------------------------
----this part will create a table in the database if it doesn't exist


local lotteryExe = CharDBExecute([[
     CREATE TABLE IF NOT EXISTS lottery (
         week_number INT UNSIGNED NOT NULL,
         number1 INT UNSIGNED NOT NULL,
         number2 INT UNSIGNED NOT NULL,
         number3 INT UNSIGNED NOT NULL,
         number4 INT UNSIGNED NOT NULL,
         number5 INT UNSIGNED NOT NULL,
         number6 INT UNSIGNED NOT NULL,
         amount INT UNSIGNED NOT NULL,
         PRIMARY KEY (week_number)
     )
 ]])

local lotteryTicketExe = CharDBExecute([[
    CREATE TABLE IF NOT EXISTS lottery_tickets (
        ticket_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        week_number INT UNSIGNED NOT NULL,
        player_guid INT UNSIGNED NOT NULL,
        player_account_id INT UNSIGNED NOT NULL,
        number1 INT UNSIGNED NOT NULL,
        number2 INT UNSIGNED NOT NULL,
        number3 INT UNSIGNED NOT NULL,
        number4 INT UNSIGNED NOT NULL,
        number5 INT UNSIGNED NOT NULL,
        number6 INT UNSIGNED NOT NULL,
        PRIMARY KEY (ticket_id),
        FOREIGN KEY (week_number) REFERENCES lottery(week_number)
    )

     ]])

if (lotteryExe == false) then
    print("Error creating lottery table")
end

if (lotteryTicketExe == false) then
    print("Error creating lottery_tickets table")
end


-----------------------------------------------------

local function LotteryOnLogin(event, player)
    local guid = player:GetGUIDLow()
    lottery_tickets[guid] = {}
    local tickets = CharDBQuery("SELECT * FROM lottery_tickets WHERE player_guid=" .. guid)

    -----------------------------------------------------
    if (tickets) then
        while (tickets:NextRow()) do
            local ticket = {
                ticket_id = tickets:GetUInt32(0),
                week_number = tickets:GetUInt32(1),
                player_guid = tickets:GetUInt32(2),
                player_account_id = tickets:GetUInt32(3),
                number1 = tickets:GetUInt32(4),
                number2 = tickets:GetUInt32(5),
                number3 = tickets:GetUInt32(6),
                number4 = tickets:GetUInt32(7),
                number5 = tickets:GetUInt32(8),
                number6 = tickets:GetUInt32(9)
            }

            --Add the ticket to the lookup table
            if lottery_tickets[guid] == nil then
                lottery_tickets[guid] = {}
            end

            lottery_tickets[guid][ticket.ticket_id] = ticket
        end
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, LotteryOnLogin)
--------------------------------------------------------

-- --RegisterPlayerEvent for when a player logs out
-- function LotteryOnLogout(event, player)
--     --Remove the entry from the lottery_tickets table
--     if (lottery_tickets[player:GetGUIDLow()]) then
--         lottery_tickets[player:GetGUIDLow()] = nil
--     end
-- end

-- RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, LotteryOnLogout)
local function LotteryOnLogout(event, player)
    lottery_tickets[player:GetGUIDLow()] = nil
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, LotteryOnLogout)
--------------------------------------------------------------------------------------------------------------------

local function LotteryTicketEventEnd(event, gameeventid)
    if (gameeventid ~= 200) then return end

    local result = CharDBQuery("SELECT week_number FROM lottery ORDER BY week_number DESC LIMIT 1")
    if not result then return end
    local week_number = result:GetUInt32(0)

    local lot = CharDBQuery("SELECT number1, number2, number3, number4, number5, number6, amount FROM lottery WHERE week_number=" .. week_number)
    if not lot then return end

    local number1, number2, number3, number4, number5, number6, amount =
        lot:GetUInt32(0), lot:GetUInt32(1), lot:GetUInt32(2),
        lot:GetUInt32(3), lot:GetUInt32(4), lot:GetUInt32(5),
        lot:GetUInt32(6)

    local winners = {}
    local tickets = CharDBQuery("SELECT * FROM lottery_tickets WHERE week_number=" .. week_number)
    if tickets then
        while tickets:NextRow() do
            if tickets:GetUInt32(4) == number1 and
               tickets:GetUInt32(5) == number2 and
               tickets:GetUInt32(6) == number3 and
               tickets:GetUInt32(7) == number4 and
               tickets:GetUInt32(8) == number5 and
               tickets:GetUInt32(9) == number6 then
                table.insert(winners, tickets:GetUInt32(2)) -- player_guid
            end
        end
    end

    if #winners > 0 then
        local winnings = math.floor(amount / #winners)
        for _, guid in ipairs(winners) do
            SendMail("Lottery Winner!", "Congratulations! You won " .. winnings .. " copper!", guid, 0, 0, 0, winnings)
            local q = CharDBQuery("SELECT name FROM characters WHERE guid=" .. guid)
            if q then
                SendWorldMessage("|cffFFD700[Lottery]|r " .. q:GetString(0) .. " has won the lottery jackpot!")
            end
        end

        -- Start a new week since someone won
        local next_week = week_number + 1
        local n1, n2, n3, n4, n5, n6 = math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9), math.random(0,9)
        local starting_pot = 10000000 -- 1000g
        CharDBExecute(string.format("INSERT INTO lottery (week_number, number1, number2, number3, number4, number5, number6, amount) VALUES (%d,%d,%d,%d,%d,%d,%d,%d)",
            next_week, n1,n2,n3,n4,n5,n6, starting_pot))
        SendWorldMessage("|cffFFD700[Lottery]|r A new lottery week has begun! Jackpot starts at 1000 gold.")
    else
        -- carry over jackpot
        SendWorldMessage("|cffFFD700[Lottery]|r No winners this week. Jackpot carries over!")
    end

    -- ✅ Always remove old tickets at the end of the draw
    CharDBExecute("DELETE FROM lottery_tickets WHERE week_number=" .. week_number)
end



RegisterServerEvent(GAME_EVENT_STOP, LotteryTicketEventEnd)

-----------------------------------------------------

local function LotteryTicketEventBegin(event, gameeventid)
    if (gameeventid ~= 200) then return end

    -- Get the most recent lottery week
    local week_result = CharDBQuery("SELECT week_number, amount FROM lottery ORDER BY week_number DESC LIMIT 1")
    local week_number = 0

    if week_result then
        week_number = week_result:GetUInt32(0)
        local jackpot_amount = week_result:GetUInt32(1)

        -- Resume existing lottery
        SendWorldMessage("|cffFFD700[Lottery]|r The current lottery continues! Jackpot is at "
            .. math.floor(jackpot_amount / 10000) .. " gold. Buy your tickets now!")

    else
        -- No lottery exists yet → create the first week
        week_number = 1
        local n1, n2, n3, n4, n5, n6 =
            math.random(0, 9), math.random(0, 9), math.random(0, 9),
            math.random(0, 9), math.random(0, 9), math.random(0, 9)

        local starting_pot = 10000000 -- 1000 gold

        CharDBExecute(string.format(
            "INSERT INTO lottery (week_number, number1, number2, number3, number4, number5, number6, amount) " ..
            "VALUES (%d,%d,%d,%d,%d,%d,%d,%d)",
            week_number, n1, n2, n3, n4, n5, n6, starting_pot
        ))

        SendWorldMessage("|cffFFD700[Lottery]|r A new lottery week has started with a jackpot of 1000 gold!")
    end
end



RegisterServerEvent(GAME_EVENT_START, LotteryTicketEventBegin)

--------------------------------------------------------------------------------------------------------------------

local function LotteryGossipNpc(event, player, creature)
    local query = CharDBQuery("SELECT amount FROM lottery WHERE week_number=(SELECT MAX(week_number) FROM lottery)")
    local jackpot_amount = 0
    if query then
        jackpot_amount = query:GetUInt32(0)
    end
    local jackpot_amount_gold = math.floor(jackpot_amount / 10000)

    -- Clear the gossip menu first
    player:GossipClearMenu()

    -- Add a "text" line using a disabled menu item (0) that cannot be selected
    player:GossipMenuAddItem(0, 
        SetColor("FF000000", "Current lottery jackpot: ") .. 
        SetColor("FFFFD700", tostring(jackpot_amount_gold)) .. " gold!", 
        0, 0
    )

    local ticket_count = 0
if lottery_tickets[player:GetGUIDLow()] then
    -- Collect keys into an array
    local keys = {}
    for k in pairs(lottery_tickets[player:GetGUIDLow()]) do
        table.insert(keys, k)
    end
    table.sort(keys) -- sort numerically

    for _, k in ipairs(keys) do
        local ticket = lottery_tickets[player:GetGUIDLow()][k]
        local ticket_string = string.format(
            "Ticket #%u: %u, %u, %u, %u, %u, %u",
            ticket.ticket_id,
            ticket.number1,
            ticket.number2,
            ticket.number3,
            ticket.number4,
            ticket.number5,
            ticket.number6
        )
        player:GossipMenuAddItem(0, ticket_string, 0, 0)
        ticket_count = ticket_count + 1
    end
end


    if ticket_count == 3 then
        player:GossipMenuAddItem(0, "You have reached the maximum amount of tickets you can purchase.", 0, 0)
    elseif ticket_count < 3 then
        player:GossipMenuAddItem(0, "Purchase Ticket: 10 gold", 0, 1)
    end

    player:GossipSendMenu(menuId, creature)
end


local function LotteryGossipNpcSelect(event, player, creature, sender, intid)
    if intid ~= 1 then return end

    -- Check if the player has enough money
    if player:GetCoinage() < 100000 then
        creature:SendUnitSay("You do not have enough money to buy a lottery ticket!", 0)
        return
    end

    -- Subtract the money from the player
    player:ModifyMoney(-100000)

    -- Generate the 6 lottery numbers
    local number1 = math.random(0, 9)
    local number2 = math.random(0, 9)
    local number3 = math.random(0, 9)
    local number4 = math.random(0, 9)
    local number5 = math.random(0, 9)
    local number6 = math.random(0, 9)

    -- Get the current week number safely
    local week_query = CharDBQuery("SELECT week_number FROM lottery ORDER BY week_number DESC LIMIT 1")
    local week_number = 0
    if week_query then
        week_number = week_query:GetUInt32(0)
    else
        -- fallback: if no week exists yet, create the first week
        week_number = 1
        CharDBExecute(
            string.format(
                "INSERT INTO lottery (week_number, number1, number2, number3, number4, number5, number6, amount) VALUES (%d, %d, %d, %d, %d, %d, %d, 0)",
                week_number, number1, number2, number3, number4, number5, number6
            )
        )
    end

    -- Increase the amount in the pot by 70000 copper
    CharDBExecute("UPDATE lottery SET amount=amount+70000 WHERE week_number=" .. week_number)

    CharDBExecute(
    string.format(
        "INSERT INTO lottery_tickets (week_number, player_guid, player_account_id, number1, number2, number3, number4, number5, number6) VALUES (%d, %d, %d, %d, %d, %d, %d, %d, %d)",
        week_number, player:GetGUIDLow(), player:GetAccountId(),
        number1, number2, number3, number4, number5, number6
    )
)

    -- Get the new ticket_id safely
    local ticket_query = CharDBQuery("SELECT ticket_id FROM lottery_tickets ORDER BY ticket_id DESC LIMIT 1")
    local ticket_id = 0
    if ticket_query then
        ticket_id = ticket_query:GetUInt32(0)
    end

    -- Add the ticket to the player's session
    local new_ticket = {
        ticket_id = ticket_id,
        week_number = week_number,
        player_guid = player:GetGUIDLow(),
        player_account_id = player:GetAccountId(),
        number1 = number1,
        number2 = number2,
        number3 = number3,
        number4 = number4,
        number5 = number5,
        number6 = number6
    }

    if lottery_tickets[player:GetGUIDLow()] == nil then
        lottery_tickets[player:GetGUIDLow()] = {}
    end
    lottery_tickets[player:GetGUIDLow()][new_ticket.ticket_id] = new_ticket

    creature:SendUnitSay("Your lottery ticket has been purchased! Good luck!", 0)

    -- Refresh the gossip menu
    LotteryGossipNpc(event, player, creature)
end


RegisterCreatureGossipEvent(npcId, GOSSIP_EVENT_ON_HELLO, LotteryGossipNpc)
RegisterCreatureGossipEvent(npcId, GOSSIP_EVENT_ON_SELECT, LotteryGossipNpcSelect)

local function onSpawnNpc(event, creature) creature:SetNPCFlags(3) end

RegisterCreatureEvent(npcId, 5, onSpawnNpc)
