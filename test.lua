local json = require('cjson')
local api = require('litepms.api')
local date = require("date")

local methods = {
	api.hotel.info(),
	api.booking.fields(),
	api.bookings.get(),
	api.bookings.get(date():adddays(-2):fmt("%Y-%m-%d"),date():fmt("%Y-%m-%d")),
	api.booking.get(),
	api.booking.create({
		['client_name'] = 'test',
		['date_in'] = date():fmt("%Y-%m-%d"),
		['date_out'] = date():adddays(-2):fmt("%Y-%m-%d"),
		['person'] = 1
	})	
}

for _,method in pairs(methods) do
	print('-------------------------------\n\n')
	local result,err = method
	print (err)
	print (json.encode(result))
end




