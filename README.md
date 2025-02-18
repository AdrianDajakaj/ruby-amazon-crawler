# Amazon Product Crawler in Ruby

A web scraper implemented in Ruby that extracts product information from Amazon using Nokogiri and stores it in an SQLite database. (On the example of the cellphone category and the keyword "cellphone cases")

## Features

- 🌐 Scrapes product details including title, price, rating, and category
- 📊 Saves extracted data in JSON format
- 🗄️ Stores data in an SQLite database using Sequel
- 🔍 Configurable product selectors for different categories
- 🚀 Supports pagination to scrape multiple pages
- 🛠️ Error handling and retry mechanisms
- 🔎 Supports scraping by both category and keyword search
- 🔗 Stores links to product pages and extracts detailed data from individual product pages

## Installation & Running

1. Clone the repository:
    ```bash
    git clone https://github.com/your-username/ruby-amazon-crawler.git
    cd ruby-amazon-crawler
    ```

2. Install dependencies:
    ```bash
    bundle install
    ```

3. Run the crawler:
    ```bash
    ruby crawler.rb
    ```

## How It Works

The crawler extracts product details by parsing Amazon product listing pages and individual product pages using Nokogiri. The extracted data is saved both in JSON files and an SQLite database.

### Data Extraction
- **Title** - Extracted from product listings
- **Price** - Whole number and fractional values combined
- **Currency** - Extracted from the price symbol
- **Rating** - Parsed from star rating elements
- **Number of Reviews** - Extracted from the review count section
- **Category** - Extracted from breadcrumb navigation
- **Additional Product Info** - Extracted from the product specification table

### Database Storage
The extracted product data is stored in an SQLite database (`amazon_products.db`).
- The script dynamically adds missing columns when new product attributes appear.
- Data is inserted after successful extraction.

## Key Components

### Core Functions
- `products_scrape(url_suffix, selectors, page_limit, datapath)` - Scrapes product listings and saves data to JSON.
- `single_product_scrape(product_url, selectors)` - Scrapes product details from an individual page.
- `add_data_to_db(database, table_name, datapath)` - Loads JSON data and inserts it into an SQLite database.
- `load_json_data(datapath)` - Reads and parses a JSON file.

### Configuration
Product selectors are defined as hashes, making it easy to adjust them for different product categories.

```ruby
category_selectors = {
  'products_selector' => 'div.s-result-item',
  'title_selector' => 'h2.a-size-medium',
  'price_whole_selector' => 'span.a-price-whole',
  'price_fraction_selector' => 'span.a-price-fraction',
  'rate_selector' => 'i.a-icon-star',
  'num_of_rates_selector' => '#acrCustomerReviewText',
  'categories_selector' => '#wayfinding-breadcrumbs_feature_div li a',
}
```

## Save System Details
Extracted product data is saved in JSON format:

- `amazon_data_by_category.json`
- `amazon_data_by_keyword.json`

Each JSON file contains an array of product details, which can be later inserted into the database.

## Error Handling
The script includes basic error handling for:
- **HTTP errors** when fetching pages
- **JSON parsing errors** when loading data
- **Unexpected missing elements** in scraped pages

## Requirements
- Ruby 2.7+
- Bundler (`gem install bundler`)
- SQLite3
- Required Gems:
  - Nokogiri
  - Sequel
  - OpenURI

## Contributing
Contributions are welcome! Please follow best practices for Ruby coding and ensure compatibility with different Ruby versions.

