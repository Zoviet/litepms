local json = require('cjson')
local cURL = require("cURL")
local date = require("date")
local log = require('utils.log')
local config = require('config.litepms')

local _M = {}
_M.result = nil
_M.base = 'https://litepms.ru/api/'
_M.auth = '?login='..config.login..'&hash='..config.hash
_M.booking = {}
_M.bookings = {}
_M.client = {}
_M.clients = {}
_M.room = {}
_M.rooms = {}
_M.doc = {}
_M.coupon = {}
_M.invoice = {}
_M.categories = {}
_M.category = {}
_M.hotel = {}
_M.cashbox = {}

log.outfile = 'logs/litepms_'..os.date('%Y-%m-%d')..'.log' 
log.level = 'trace'	

function query(data)
	if not data then return _M.auth end
	local str = _M.auth
	for k,v in pairs(data) do str = str..'&'..k..'='..v end
	return str
end

function get_result(str,url)
	local result, err = pcall(json.decode,str)
	if result then
		_M.result = json.decode(str)
		if _M.result.status and  _M.result.status == 'error' then
			log.error(url..':'..json.encode(_M.result.error))
			return nil,	_M.result.error
		end
	else				
		log.error(url..':'..err)
		return nil,	err
	end	
	return _M.result
end

function poster(data)
	local result = {}
	for i,k in pairs(data) do table.insert(result, i..'='..k) end
	return table.concat(result,'&')
end

function _M.get(url,data)
	local str = ''
	url =  _M.base..url..query(data)
	local headers = {
		'Content-type: application/json',
		'Accept: application/json'
	}
	local c = cURL.easy{		
		url = url,	
		httpheader  = headers,	
		writefunction = function(st)	
			str = str..st
		end
	}
	local ok, err = c:perform()	
	c:close()
	if not ok then return nil, err end
	local res,err = get_result(str,url)
	if not res then return nil,err end
	if res.status ~= 'success' then return nil, 'Неудача получения данных' end
	return res.data
end

function _M.post(url,data,add)
	local str = ''
	url = _M.base..url..query(add)
	local headers = {
		'Content-type: application/x-www-form-urlencoded',
		'Accept: application/json'
	}
	local c = cURL.easy{		
		url = url,		
		post = true,
		postfields = poster(data),	
		httpheader  = headers,
		writefunction = function(st)		
			str = str..st
		end
	}
	local ok, err = c:perform()	
	c:close()
	if not ok then return nil, err end
	local res,err = get_result(str,url)
	if not res then return nil,err end
	if res.status and res.status ~= 'success' then return nil, 'Неудача получения данных' end
	if not res.status and not res.success then return nil, 'Неудача добавления/обновления' end
	if res.page then return {['page'] = res.page, ['pages'] = res.pages, ['count'] = res.count, ['data'] = res.data} end
	if res.data then return res.data end
	return res.response
end

-- Получение информации об объекте.

function _M.hotel.info()
	return _M.get('getHotelInfo')
end

-- Получение информации обо всех полях используемых в бронировании.

function _M.booking.fields()
	return _M.get('getBookingFields')
end

-- Получение информации о всех бронированиях, в которых происходили изменения в заданный промежуток времени. Возвращается список ID бронирований. Без параметров - брони на месяц вперед от даты запроса.

function _M.bookings.get(start,finish)
	if start then start = date(start):fmt("%Y-%m-%d") else start = date():adddays(-30):fmt("%Y-%m-%d") end
	if finish then finish = date(finish):fmt("%Y-%m-%d") else finish = date():fmt("%Y-%m-%d") end
	return(_M.get('getBookings',{['start']=start,['finish']=finish}))
end

-- Получение информации о конкретном бронировании. Назначение полей описано в методе getBookingFields.

function _M.booking.get(id)	
	return _M.get('getBooking',{['id']=id})
end

-- Создание бронирования. При создании бронирования может быть создана запись о клиенте, поэтому отдельный запрос на создание клиента выполнять не требуется.

function _M.booking.create(data)
	if type(data.client_name) ~= 'string' then return nil, 'Имя клиента должно быть обязательно указано и быть строкой' end
	if not data.room_id then return nil, 'Не указан id номера размещения' end
	data.status_id = data.status_id or 0 
	data.person = data.person or 0 
	if not data.date_in then return nil, 'Не указано время заезда' else data.date_in = date(data.date_in):fmt("%Y-%m-%d") end
	if not data.date_out then return nil, 'Не указано время заезда' else data.date_out = date(data.date_out):fmt("%Y-%m-%d") end
	return _M.post('createBooking',data)	
end

-- Обновление информации о бронировании и клиенте.

function _M.booking.update(id,data)
	if data then data.id = id else return nil, 'Не передан id для обновления брони' end
	return _M.post('updateBooking',data)
end

-- Перевод брони в статус "отменено"

function _M.booking.cancel(id)
	if not id then return nil, 'Не передан id брони для ее отмены' end
	return _M.post('updateBooking',{['id'] = id, ['status_id'] = 3})
end

-- Получение списка клиентов. Возможно использование фильтра. Параметры передаются методом GET.

function _M.clients.get(filters)
	return _M.get('getClients',filters)
end

-- Получение информации о конкретном клиенте.

function _M.client.get(id)
	return _M.get('getClient',{['id']=id})
end

-- Создание записи о клиенте

function _M.client.create(data)
	if type(data.name) ~= 'string' then return nil, 'Имя клиента должно быть обязательно указано и быть строкой' end
	return _M.post('createClient',data)
end

-- Получение списка номеров. Если передается параметр room_id, будет возвращена информации о конкретном номере.

function _M.rooms.get(room_id)
	return _M.get('getRooms',{['room_id']=room_id})
end

-- Получение номера

function _M.room.get(room_id)
	if not room_id then return nil, 'Не передан id комнаты/квартиры/номера' end
	return _M.rooms.get(room_id)
end

-- Получение списка категорий. Если передается параметр cat_id, будет возвращена информации о конкретной категории.

function _M.categories.get(cat_id)
	return _M.get('getCategories',{['cat_id']=cat_id})
end

-- Получение категории

function _M.category.get(cat_id)
	if not cat_id then return nil, 'Не передан id категории' end
	return _M.categories.get(cat_id)
end

-- Получение списка тарифов для номера.

function _M.rooms.rates(room_id)
	return _M.get('getRoomRates',{['room_id']=room_id})
end

-- Получение списка тарифов для категории.

function _M.category.rates(cat_id)
	return _M.get('getCatRates',{['cat_id']=cat_id})
end

-- Получение полного списка тарифов созданный в вашем аккаунте.

function _M.rates()
	return _M.get('getRates')
end

-- Получение информации о свободных и занятых номерах, загрузке объекта за выбранный период по дням.

function _M.occupancy(from_date,to_date)
	if from_date then from_date = date(from_date):fmt("%Y-%m-%d") else from_date = date():fmt("%Y-%m-%d") end
	if to_date then to_date = date(to_date):fmt("%Y-%m-%d") else to_date = date():adddays(30):fmt("%Y-%m-%d") end
	return(_M.get('getOccupancy',{['from_date']=from_date,['to_date']=to_date}))
end

-- Получение информации о всех операциях в кассе за выбранный период по дням.

function _M.cashbox.transaction(filters)
	return _M.get('getCashboxTransaction',filters)
end

-- Получение списка свободных номеров на указанные даты заезда и выезда.

function _M.rooms.free(data)
	if not data.date_in then return nil, 'Не указана начальная дата периода' else data.date_in = date(data.date_in):fmt("%Y-%m-%d") end
	if not data.date_out then return nil, 'Не указана конечная дата периода' else data.date_out = date(data.date_out):fmt("%Y-%m-%d") end
	return _M.get('getFreeRooms',data)
end

-- Получение календаря доступности по всем номерам на каждый день из указанного периода.

function _M.rooms.freebydates(data)
	if not data.date_in then return nil, 'Не указана начальная дата периода' else data.date_in = date(data.date_in):fmt("%Y-%m-%d") end
	if not data.date_out then return nil, 'Не указана конечная дата периода' else data.date_out = date(data.date_out):fmt("%Y-%m-%d") end
	return _M.get('getFreeRoomsByDates',data)
end

-- Поиск броней по указанным параметрам. Все параметры в запросе должны передаваться методом POST

function _M.booking.search(data)
	if not data.date_in then return nil, 'Не указана начальная дата периода' else data.date_in = date(data.date_in):fmt("%Y-%m-%d") end
	if not data.date_out then return nil, 'Не указана конечная дата периода' else data.date_out = date(data.date_out):fmt("%Y-%m-%d") end
	return _M.post('searchBooking',data)
end

function _M.booking.search(data)
	if not data.from_date then return nil, 'Не указана начальная дата периода' else data.date_in = date(data.date_in):fmt("%Y-%m-%d") end
	if not data.to_date then return nil, 'Не указана конечная дата периода' else data.date_out = date(data.date_out):fmt("%Y-%m-%d") end
	return _M.post('searchBooking',data)
end

function _M.bookings.period(start,finish)
	if start then start = date(start):fmt("%Y-%m-%d") else start = date():fmt("%Y-%m-%d") end
	if finish then finish = date(finish):fmt("%Y-%m-%d") else finish = date():adddays(30):fmt("%Y-%m-%d") end
	return _M.booking.search({['from_date']=start,['to_date']=finish})
end

-- Получение заполненной печатной формы в формате PDF или HTML.

function _M.doc.get(data)
	return _M.get('getDoc',data)
end

-- Получение списка шаблонов печатных форм

function _M.doc.template()
	return _M.get('getDocTemplate')
end

-- Создание промокода. Параметры передаются методом POST.

function _M.coupon.create(data)
	if not data.title then return nil, 'Не указан заголовок купона' end
	if not data.code then return nil, 'Не указан код купона' end
	return _M.post('createCoupon',data)
end

-- Обновление промокода. Параметры передаются методом POST.

function _M.coupon.update(id,title,code,data)
	if not id then return nil, 'Не указан id купона' else data.id = id end
	if not title then return nil, 'Не указан заголовок купона' else data.title = title end
	if not code then return nil, 'Не указан код купона' else data.code = code end
	return _M.post('updateCoupon',data)
end

-- Создание счета для брони. Параметры передаются методом POST.

function _M.invoice.create(data)
	if not data.booking_id then return nil, 'Не указан id бронирования' end
	return _M.post('createInvoice',data)
end

return _M
