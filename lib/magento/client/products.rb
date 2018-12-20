## API endpoints to products

module Magento
  class Client
    module Products

      attr_reader :product_filters

      ##=======
      # searchCriteria[filterGroups][][filters][][field] string
      # searchCriteria[filterGroups][][filters][][value] string
      # searchCriteria[filterGroups][][filters][][conditionType]
      # searchCriteria[sortOrders][][field] string
      # searchCriteria[sortOrders][][direction] string
      # searchCriteria[pageSize] integer
      # searchCriteria[currentPage] integer

      # e.g.
      # filters = {filter_groups: [{filters: [{field: 'category_id', value: 1, condition: 'eq'}],
      #             [{field: 'price', value: 100, condition: 'eq'}]}],
      #             order: [{field: 'name', direction: 'ABC'}]}
      # get_products(1, 10, filters)

      # To perform a logical OR, specify multiple filters within a filter_groups
      # To perform a logical AND, specify multiple filter_groups.
      ##=======

      def get_products_through_extension(page, per_page, store_id, magento_version, additional_attributes, filters = {})
        @product_filters = product_visibility_filters(store_id, magento_version) + prepare_filters(filters, page, per_page, 2, additional_attributes)
        products = get_wrapper('/V1/dcapi/products?' + product_filters, default_headers).first
        return [] unless products.present?
        products.map{|product| product.deep_symbolize_keys}
      end

      def get_products(page, per_page, store_id, magento_version, filters = {})
        @product_filters = product_visibility_filters(store_id, magento_version) + prepare_filters(filters, page, per_page, 2)
        result, status = get_wrapper('/V1/products?' + product_filters, default_headers)
        return result, status unless status
        return parse_products(result), status
      end

      # Get all filters from magento
      def get_product_filters(category_id = nil)
        get_wrapper("/V1/products/filters#{'?cat=' + category_id if category_id.present?}", default_headers)
      end

      # Get specific product by sku
      def get_product_by_sku(sku)
        result, status = get_wrapper("/V1/products/#{sku}", default_headers)
        # get_wrapper("/V1/products/#{sku}", default_headers)
        return result, status unless status
        return parse_product!(result), status
      end

      def get_product_stock_by_sku(sku)
        get_wrapper("/V1/stockStatuses/#{sku}", default_headers).first['stock_item']
      end

      # Get all categories from magento
      def get_categories_list(store_id, magento_version)
        get_wrapper("/V1/categories#{'?' + specific_store_filters(store_id) if supports_store_filter?(magento_version)}", default_headers)
      end

      ## values e.g. [13, 10, 1]
      def get_product_attribute_values(attribute_id, store_id, magento_version, values = [])
        return [] unless values.present?
        result, status = get_wrapper("/V1/products/attributes/#{attribute_id}#{'?' + specific_store_filters(store_id) if supports_store_filter?(magento_version)}", default_headers)
        return result, status unless status
        return parse_attributes_by_values(result, values).first
      end

      # Get specific category by id
      def get_category_by_id(id)
        result = get_wrapper("/V1/categories/#{id}", default_headers)
        return result
      end

      # Get configurable products
      def get_configurable_products(sku, store_id, magento_version)
        configurable_products = get_wrapper("/V1/configurable-products/#{sku}/children#{'?' + specific_store_filters(store_id) if supports_store_filter?(magento_version)}", default_headers).first
        return [] unless configurable_products.present?

        products = []
        configurable_products.each do |product|
          products << parse_product!(product)
        end
        products
      end

      # Get all attributes from attribute set
      def get_attributes_by_attribute_set(attribute_set_id, store_id, magento_version)
        # return [] unless values.present?
        get_wrapper("V1/products/attribute-sets/#{attribute_set_id}/attributes#{'?' + specific_store_filters(store_id) if supports_store_filter?(magento_version)}", default_headers).first || []
        # return parse_attributes_by_values(result, values).first
      end

      def get_store_groups
        get_wrapper("/V1/store/storeGroups", default_headers).first
      end

      def get_store_configs
        get_wrapper("V1/store/storeConfigs", default_headers).first
      end

      private

      # Parse products hash from search products method
      def parse_products(products)
        return [] unless products['items'].present?

        result = products.dup
        result['items'].each do |item|
          parse_product!(item)
        end
        result
      end

      # Parse hash of one product
      def parse_product!(product)
        custom_attr = product['custom_attributes']
        custom_attr.each do |attr|
          product[attr['attribute_code']] = attr['value']
        end
        product
      end

      # Parse categories with change input hash
      def parse_categories!(categories)
        categories['children_data'].select! do |category|
          category['is_active']
        end
        categories['children_data'].each do |category|
          parse_categories!(category)
        end
        categories['children_data']
      end

      # Parse categories list from get categories method
      def parse_categories(categories)
        categories_clone = categories.dup
        parse_categories!(categories_clone)
      end

      # Parse product option attributes and return only included in product selections
      def parse_attributes_by_values(attributes, values)
        result = []
        values = values.map(&:to_s)
        attributes['options'].each do |option|
          if values.include? option['value'].to_s
            result.push({ label: option['label'], value: option['value'] })
          end
        end
        result
      end

      # Default visibility filters for exclude
      # in search disabled products and not visibly
      def product_visibility_filters(store_id, magento_version)
        products_filters = "searchCriteria[filter_groups][0][filters][0][field]=status&"+
                          +"searchCriteria[filter_groups][0][filters][0][value]=1&"+
                          +"searchCriteria[filter_groups][0][filters][0][condition_type]=eq&"+
                          +"searchCriteria[filter_groups][1][filters][0][field]=visibility&"+
                          +"searchCriteria[filter_groups][1][filters][0][value]=2,3,4&"+
                          +"searchCriteria[filter_groups][1][filters][0][condition_type]=in&"

        products_filters = supports_store_filter?(magento_version) ? products_filters + "#{specific_store_filters(store_id)}" : products_filters
      end

      def specific_store_filters(store_id)
        +"searchCriteria[filter_groups][2][filters][0][field]=store&"+
        +"searchCriteria[filter_groups][2][filters][0][value]=#{store_id}&"+
        +"searchCriteria[filter_groups][2][filters][0][condition_type]=eq&"
      end

      def supports_store_filter?(magento_version)
        magento_version >= 2.2
      end
    end
  end
end
