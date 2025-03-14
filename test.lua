local json = require('cjson')
local api = require('litepms.api')
local date = require("date")

local methods = {
	api.hotel.info(),
	api.booking.fields()		
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
	print(json.encode(res))
	local booking = api.booking.get(res.id)
	local bookings,err = api.bookings.period(start,ends)
	if bookings.data then
		for _,book in pairs(bookings.data) do
			if booking.booking_id == book.booking_id then print('Success') end
		end
	end
	api.booking.cancel(res.id) 
end

test_booking()

local room = api.room.get(68205)

for _,method in pairs(methods) do
	local result,err = method
	if not result then print(err) end
end




