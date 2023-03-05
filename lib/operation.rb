require_relative '../constants'

module Lib
  module Operation
    include Constants

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
      when INCREASED_CASHBACK
        return "Дополнительный кэшбек #{product&.[](:value)}%"
      when DISCOUNT
        return "Дополнительная скидка #{product&.[](:value)}%"
      when NOLOYALTY
        return DOESNT_PARTICIPATE
      end
    end
    
    def loyalty_discount_precent(templates, user)
      templates.where(id: user[:template_id]).first[:discount]
    end

    def discount_percent(product, templates, user)
      case product&.[](:type)
      when INCREASED_CASHBACK
        return loyalty_discount_precent(templates, user).to_f
      when DISCOUNT
        return product[:value].to_f + loyalty_discount_precent(templates, user)
      else
        0.0
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
        .reduce(0) { _2[:type] == NOLOYALTY ? _1 : _1 + (_2[:price] * _2[:quantity] - _2[:discount_summ]) }
      total_cost_of_eligible_positions <= user[:bonus].to_i ? total_cost_of_eligible_positions : user[:bonus].to_i
    end

    def total_discount_sum(products, templates, user)
      positions_payload(products, templates, user).reduce(0) { _1 + _2[:discount_summ] }
    end

    def discount_value(products, templates, user)
      (total_discount_sum(products, templates, user) / total_summ_without_discount(products, templates, user) * 100).round(2)
    end

    def loyalty_cashback_precent(templates, user)
      templates.where(id: user[:template_id]).first[:cashback]
    end

    def cashback_will_add(products, templates, user)
      (positions_payload(products, templates, user)
      .reduce(0) { _2[:type] == INCREASED_CASHBACK ? _1 + (_2[:price] * _2[:quantity] - _2[:discount_summ]) * _2[:value].to_f / 100 : _1}
      .+(allowed_summ(products, templates, user) * loyalty_cashback_precent(templates, user) / 100)).to_i
    end

    def cashback_value(products, templates, user)
      (cashback_will_add(products, templates, user).to_f / total_summ_without_discount(products, templates, user) * 100).round(2)
    end
  end
end