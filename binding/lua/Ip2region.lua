--[[
Ip2region lua binding

@author chenxin<chenxin619315@gmail.com>
@date   2018/10/02
]]--

require("bit32");

local Ip2region = {
    dbFileHandler = "",
    HeaderSip = "", 
    HeaderPtr = "",
    headerLen = "",
    firstIndexPtr = "",
    lastIndexPtr = "", 
    totalBlocks = "",
    dbBinStr = "",
    dbFile = ""
};



--[[
internal function to get a integer from a binary string

@param  dbBinStr
@param  idx
@return Integer
]]--
function getLong(bs, idx)
    local a1 = string.byte(string.sub(bs, idx, idx));
    local a2 = bit32.lshift(string.byte(string.sub(bs, idx+1, idx+1)),  8);
    local a3 = bit32.lshift(string.byte(string.sub(bs, idx+2, idx+2)), 16);
    local a4 = bit32.lshift(string.byte(string.sub(bs, idx+3, idx+3)), 24);

    local val = bit32.bor(a1, a2);
    val = bit32.bor(val, a3);
    val = bit32.bor(val, a4);

    return val;
end


--[[
internal function to convert the string ip to a long value

@param  ip
@return Integer
]]--
function ip2long(ip)
    local ini = 1;
    local iip = 0;
    local off = 24;
    local int = 0;
    while true do
        local pos = string.find(ip, '.', ini, true);
        if ( not pos or off <= 0 ) then
            break;
        end

        int = tonumber(string.sub(ip, ini, pos - 1));
        iip = bit32.bor(iip, bit32.lshift(int, off));
        ini = pos + 1;
        off = off - 8;
    end

    int = tonumber(string.sub(ip, ini));
    iip = bit32.bor(iip, bit32.lshift(int, off));

    return iip;
end


--[[
internal function to get the whole content of a file

@param  file
@return String
]]--
function get_file_contents(file)
    local fi = io.input(file);
    if ( not fi ) then
        return nil;
    end

    local str = io.read("*a");
    io.close();
    return str;
end




-- common constants
local INDEX_BLOCK_LENGTH  = 12;
local TOTAL_HEADER_LENGTH = 8192;

function Ip2region:new(obj)
    obj = obj or {};
    setmetatable(obj, {__index = self});
    return obj;
end

--[[
all the db binary string will be loaded into memory
then search the memory only and this will a lot faster than disk base search
@Note: invoke it once before put it to public invoke could make it thread safe

@param  ip
@return table or nil for failed
]]--
function Ip2region:memorySearch(ip)
    -- check and load the binary string for the first time
    if ( self.dbBinStr == "" ) then
        self.dbBinStr = get_file_contents(self.dbFile);
        if ( not self.dbBinStr ) then
            return nil;
        end

        self.firstIndexPtr = getLong(self.dbBinStr, 1);
        self.lastIndexPtr  = getLong(self.dbBinStr, 5);
        self.totalBlocks   = (self.lastIndexPtr - self.firstIndexPtr)/INDEX_BLOCK_LENGTH + 1;
    end

    if ( type(ip) == "string" ) then
        ip = ip2long(ip);
    end;

    -- binary search to define the data
    local l = 0;
    local h = self.totalBlocks;
    local dataPtr = 0;
    while ( l <= h ) do
        local m = math.floor((l + h) / 2);
        local p = self.firstIndexPtr + m * INDEX_BLOCK_LENGTH;
        local sip = getLong(self.dbBinStr, p + 1);
        if ( ip < sip ) then
            h = m - 1;
        else
            local eip = getLong(self.dbBinStr, p + 5);  -- 4 + 1
            if ( ip > eip ) then
                l = m + 1;
            else
                dataPtr = getLong(self.dbBinStr, p + 9); -- 8 + 1
                break;
            end
        end
    end

    -- not matched just stop it here
    if ( dataPtr == 0 ) then return nil end

    -- get the data
    local dataLen = bit32.band(bit32.rshift(dataPtr, 24), 0xFF);
    dataPtr = bit32.band(dataPtr, 0x00FFFFFF);
    local dptr = dataPtr + 5;   -- 4 + 1

    return {
        city_id = getLong(self.dbBinStr, dataPtr), 
        region  = string.sub(self.dbBinStr, dptr, dptr + dataLen - 5)
    };
end


--[[
get the data block through the specified ip address 
or long ip numeric with binary search algorithm

@param  ip
@return table or nil for failed
]]--
function Ip2region:binarySearch(ip)
end


--[[
get the data block associated with the specified ip with b-tree search algorithm

@param  ip
@return table or nil for failed
]]--
function Ip2region:btreeSearch(ip)
end


return Ip2region;
