require 'nokogiri'
require 'json'
require 'open-uri'
require 'sequel'

class Crawler
  def initialize(base_url, headers)
    @base_url = base_url
    @headers = headers
    @data = []
    @product_counter = 0
  end

  private

  def single_product_scrape(product_url = "", selectors = {})
    @product_counter += 1
    puts "Scraping product: #{@product_counter}"
    sleep rand(2..5)
    product_info_dict = {}
    begin
      doc = Nokogiri::HTML(URI.open(product_url, @headers))
    rescue OpenURI::HTTPError => e
      puts "Error fetching page: #{e.message}"
    end
    begin
      product_rate = doc.at_css(selectors['rate_selector'])&.text || ''
      product_rate = product_rate[/\d+(\.\d+)?/].to_f
    rescue  StandardError => e
      product_rate = nil
    end
    product_info_dict['product_rate'] = product_rate
    begin
      product_rate_count = doc.at_css(selectors['num_of_rates_selector'])&.text || ''
      product_rate_count = product_rate_count[/\d[\d,]*/]&.delete(",")&.to_i
    rescue  StandardError => e
      product_rate_count = nil
    end
    product_info_dict['product_rate_count'] = product_rate_count

    last_category = doc.css(selectors['categories_selector']).last&.text&.strip || ''
    product_info_dict['category'] = last_category
    product_info = doc.at_css(selectors['product_info_selector'])
    if product_info
      product_info.css('tr').each do |row|
        key = row.at_css(selectors['product_info_key_selector'])&.text&.strip
        value = row.at_css(selectors['product_info_value_selector'])&.text&.strip
        key = key.downcase.gsub(/\s+/, '_')
        product_info_dict[key] = value if key && value
      end
    end
    return product_info_dict
  end

  def add_missing_columns_to_db(data, database, table_name)  
    data.each do |record|
      record.each do |key, value|
        unless database[table_name.to_sym].columns.include?(key.to_sym)
          column_type = case value
                        when Integer then Integer
                        when Float then Float
                        else String
                        end
          database.alter_table(table_name.to_sym) do
            add_column key.to_sym, column_type
          end
        end
      end
    end
  end
  
  def insert_data_to_db(data, database, table_name)
    data.each do |data_row|
      DB[table_name.to_sym].insert(data_row)
    end
  end

  def load_json_data(datapath)
    begin
      json_data = JSON.parse(File.read(datapath))
      if json_data.empty?
        puts "Warning: The JSON file is empty."
        return nil
      end
      return json_data
  
    rescue JSON::ParserError => e
      puts "JSON parsing error: #{e.message}"
      return nil
  
    rescue Errno::ENOENT => e
      puts "File not found: #{e.message}"
      return nil
  
    rescue => e
      puts "An unexpected error occurred: #{e.message}"
      return nil
    end
  end

  public

  def products_scrape(url_suffix = '', selectors = {}, page_limit, datapath)
    page_number = 1
    loop do
      if page_number > page_limit
        break
      end
      current_url = "#{@base_url}#{url_suffix}"
      current_url = current_url.sub(/page=\d+/, "page=#{page_number}")
      current_url= "#{current_url}#{page_number}"
      puts "Scraping page #{page_number}: #{current_url}"
      begin
        doc = Nokogiri::HTML(URI.open(current_url, @headers))
      rescue OpenURI::HTTPError => e
        puts "Error fetching page #{page_number}: #{e.message}"
        break
      end

      products = doc.css(selectors['products_selector'])
      break if products.empty?
      products.each do |product|
        title = product.at_css(selectors['title_selector'])&.text || ''
        price_whole = product.at_css(selectors['price_whole_selector'])&.text || ''
        price_fraction = product.at_css(selectors['price_fraction_selector'])&.text || ''
        price_currency = product.at_css(selectors['price_currency_selector'])&.text || ''
        product_link = product.at_css(selectors['product_link_selector'])&.[]('href') || ''
        full_price = "#{price_whole}#{price_fraction}" if price_whole != '' && price_fraction != ''
        begin
          full_price = full_price.to_f
        rescue  StandardError => e
          full_price = nil
        end  
        if title != '' && product_link != ''
          product_link = "#{@base_url}#{product_link.strip}"
          product_info_dict = single_product_scrape(product_link, selectors)
          @data << {
            title: title,
            price: full_price,
            price_currency: price_currency,
            product_link: product_link
          }.merge(product_info_dict)
        end
      end
      next_button = doc.at_css('a.s-pagination-next')
      break unless next_button
      page_number += 1
      sleep rand(2..5)
    end
    File.open(datapath, 'w') do |file|
      file.write(JSON.pretty_generate(@data))
    end
    puts "Data successfully extracted and saved to #{datapath}"
  end

  def add_data_to_db(database, table_name, datapath)
    json_data = load_json_data(datapath)
    if json_data
      add_missing_columns_to_db(json_data, database, table_name)
      insert_data_to_db(json_data, database, table_name)
    else
      puts "No data to add!"
    end
  end
end

headers = {
  "User-Agent" =>   "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"  ,
  "Accept-Language" => "en-US,en;q=0.9"
}

DB = Sequel.sqlite('amazon_products.db')

DB.create_table?(:products) do
  primary_key :id
  String :title
  Float :price
  String :price_currency
  String :product_link
end

category_suffix="/s?i=mobile&page=1&rh=n%3A7072561011&s=popularity-rank&fs=true&ref=sr_pg_"
category_selectors = {
  'products_selector' => 'div.sg-col-4-of-24.sg-col-4-of-12.s-result-item',
  'title_selector' => 'h2.a-size-base-plus.a-spacing-none.a-color-base.a-text-normal',
  'price_whole_selector' => 'span.a-price-whole',
  'price_fraction_selector' => 'span.a-price-fraction',
  'price_currency_selector' => 'span.a-price-symbol',
  'product_link_selector' => 'a.a-link-normal.s-line-clamp-4.s-link-style.a-text-normal',
  'rate_selector' => 'i.a-icon.a-icon-star.cm-cr-review-stars-spacing-big',
  'num_of_rates_selector' => '#acrCustomerReviewLink #acrCustomerReviewText',
  'categories_selector' => '#wayfinding-breadcrumbs_feature_div ul li a.a-link-normal.a-color-tertiary',
  'product_info_selector' => '#productOverview_feature_div table',
  'product_info_key_selector' => 'td.a-span3 span.a-size-base.a-text-bold',
  'product_info_value_selector' => 'td.a-span9 span.a-size-base.po-break-word'
}
data_path_by_category = 'amazon_data_by_category.json'

keyword = "cell+phone+cases"
keyword_suffix = "/s?k=#{keyword}&page=1&s=popularity-rank&ref=sr_pg_"
keyword_selectors = {
  'products_selector' => 'div.sg-col-20-of-24.s-result-item',
  'title_selector' => 'h2.a-size-medium.a-spacing-none.a-color-base.a-text-normal',
  'price_whole_selector' => 'span.a-price-whole',
  'price_fraction_selector' => 'span.a-price-fraction',
  'price_currency_selector' => 'span.a-price-symbol',
  'product_link_selector' => 'a.a-link-normal.s-line-clamp-2.s-link-style.a-text-normal',
  'rate_selector' => 'i.a-icon.a-icon-star.cm-cr-review-stars-spacing-big',
  'num_of_rates_selector' => '#acrCustomerReviewLink #acrCustomerReviewText',
  'categories_selector' => '#wayfinding-breadcrumbs_feature_div ul li a.a-link-normal.a-color-tertiary',
  'product_info_selector' => '#productOverview_feature_div table',
  'product_info_key_selector' => 'td.a-span3 span.a-size-base.a-text-bold',
  'product_info_value_selector' => 'td.a-span9 span.a-size-base.po-break-word'
}
data_path_by_keyword = 'amazon_data_by_keyword.json'

crawl = Crawler.new("https://www.amazon.com", headers)
crawl.products_scrape(category_suffix, category_selectors, 1, data_path_by_category)
crawl.products_scrape(keyword_suffix, keyword_selectors, 1, data_path_by_keyword)
crawl.add_data_to_db(DB, 'products', data_path_by_category)
crawl.add_data_to_db(DB, 'products', data_path_by_keyword)



