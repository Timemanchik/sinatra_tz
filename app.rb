require 'sinatra'
require 'sequel'
require 'sqlite3'
require 'json'
require 'pry'

DB = Sequel.connect('sqlite://test.db')

users = DB[:user]
operations = DB[:operation]
products = DB[:product]
templates =  DB[:template]

before do
  if request.request_method == "POST"
    body_parameters = request.body.read
    params.merge!(JSON.parse(body_parameters))
  end
end

get '/' do
  binding.pry

  {foo: DB[:user].first}.to_json
end

#   {    
#     "user": {
#         "id": 1,
#         "template_id": 1,
#         "name": "Иван",
#         "bonus": "10000.0"
#     },
#     "operation_id": 18,
#     "write_off": 150
# }

# {
#   "status": 200,
#   "message": "Данные успешно обработаны!", Операция уже проведена! 400 bad request
#   "operation": {
#       "user_id": 1,
#       "cashback": 24,
#       "cashback_percent": 0,
#       "discount": "6.0",
#       "discount_percent": "0.81",
#       "write_off": 150,
#       "check_summ": 584
#   }
# }

post '/submit' do
  { 
    status: response.status,
    message: nil,
    operation: {
      user_id: params.dig(:user, :id),
      cashback: nil,
      cashback_percent: nil,
      discount: nil,
      discount_percent: nil,
      write_off: nil,
      check_summ: nil
    }
  }.to_json
end

post '/operation' do
  
  user = users.where(id: params[:user_id]).first

  def product_find(position, products)
    products.where(id: position[:id]).first
  end

  def positions_payload(products, templates, user)
    params[:positions].map do 
      product = product_find(_1, products)
      {
        id: _1[:id],
        price: _1[:price],
        quantity: _1[:quantity],
        type: product&.[](:type),
        value: product&.[](:value),
        type_desc: type_desc(product),
        discount_percent: discount_percent(product, templates, user),
        discount_summ: discount_summ(_1, product, templates, user)
      }
    end
  end

  def type_desc(product)
    case product&.[](:type)
    when 'increased_cashback'
      return "Дополнительный кэшбек #{product&.[](:value)}%"
    when 'discount'
      return "Дополнительная скидка #{product&.[](:value)}%"
    when 'noloyalty'
      return 'Не участвует в системе лояльности'
    end
  end
  
  def loyalty_discount_precent(templates, user)
    templates.where(id: user[:template_id]).first[:discount]
  end

  def discount_percent(product, templates, user)
    case product&.[](:type)
    when 'increased_cashback'
      return loyalty_discount_precent(templates, user).to_f
    when 'discount'
      return product[:value].to_f + loyalty_discount_precent(templates, user)
    else
      return 0.0
    end
  end

  def discount_summ(position, product, templates, user)
    discount_percent(product, templates, user) * position[:price] * position[:quantity] / 100
  end

def user_payload(user)
  {
    id: user[:id],
    template_id: user[:template_id],
    name: user[:name],
    bonus: user[:bonus].to_f.to_s
  }
end

def total_summ(products, templates, user)
  positions_payload(products, templates, user).reduce(0) { _1 + _2[:price] * _2[:quantity] - _2[:discount_summ] }
end

def total_summ_without_discount(products, templates, user)
  positions_payload(products, templates, user).reduce(0) { _1 + _2[:price] * _2[:quantity] }
end

def allowed_summ(products, templates, user)
  total_cost_of_eligible_positions = positions_payload(products, templates, user)
    .reduce(0) { _2[:type] == 'noloyalty' ? _1 : _1 + (_2[:price] * _2[:quantity] - _2[:discount_summ]) }
  total_cost_of_eligible_positions <= user[:bonus].to_i ? total_cost_of_eligible_positions : user[:bonus].to_i
end

def total_discount_sum(products, templates, user)
  positions_payload(products, templates, user).reduce(0) { _1 + _2[:discount_summ] }
end

def discount_value(products, templates, user)
  "#{(total_discount_sum(products, templates, user) / total_summ_without_discount(products, templates, user) * 100).round(2)}%"
end

def loyalty_cashback_precent(templates, user)
  templates.where(id: user[:template_id]).first[:cashback]
end

def cashback_will_add(products, templates, user)
  (positions_payload(products, templates, user)
  .reduce(0) { _2[:type] == 'increased_cashback' ? _1 + (_2[:price] * _2[:quantity] - _2[:discount_summ]) * _2[:value].to_f / 100 : _1}
  .+(allowed_summ(products, templates, user) * loyalty_cashback_precent(templates, user) / 100)).to_i
end

def cashback_value(products, templates, user)
  "#{(cashback_will_add(products, templates, user).to_f / total_summ_without_discount(products, templates, user) * 100).round(2)}%"
end

  { 
    status: response.status,
    user: user_payload(user),
    operation_id: operations.all.last[:id],
    summ: total_summ(products, templates, user),
    positions: positions_payload(products, templates, user),
    discount: {
      summ: total_discount_sum(products, templates, user),
      value: discount_value(products, templates, user)
    },
    cashback: {
      existed_summ: user[:bonus].to_i,
      allowed_summ: allowed_summ(products, templates, user),
      value: cashback_value(products, templates, user),
      will_add: cashback_will_add(products, templates, user)
    }
  }.to_json
end