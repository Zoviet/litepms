local json = require('cjson')
local api = require('litepms.api')
local date = require("date")

local methods = {
	api.hotel.info(),
	api.booking.fields(),
	api.bookings.get(),
	--api.bookings.get(date():adddays(-2):fmt("%Y-%m-%d"),date():fmt("%Y-%m-%d")),
	--api.booking.get(),
	api.booking.cancel(4832620),
		
}

function test_booking()
	local start = date():fmt("%Y-%m-%d")
	local ends = date():adddays(2):fmt("%Y-%m-%d") 
	local res,err = api.booking.create({
		['client_name'] = 'test',
		['date_in'] = start,
		['date_out'] = ends,
		['person'] = 1,
		['room_id'] = 68205
	})	
	if not res then	
		api.booking.cancel(string.match(err[1],'%(INTERNAL ID: (%d+)%)')) 
		return test_booking()
	end
	api.booking.get(res.id)
	local bookings,err = api.bookings.get(start,ends)
	print(err)
	print(json.encode(bookings))
end

--api.booking.cancel(4832741),
test_booking()

--for _,method in pairs(methods) do
	print('-------------------------------\n\n')
	--local result,err = method
	--print (err)
	--print (json.encode(result))
--end




