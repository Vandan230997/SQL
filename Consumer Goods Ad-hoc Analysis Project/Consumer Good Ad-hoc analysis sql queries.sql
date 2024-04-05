use gdb023;

/* 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region. */

select distinct(market) from dim_customer 
where customer = 'Atliq Exclusive' and region = 'APAC';


/* 2. What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg */

select (select count(distinct(product_code)) from fact_sales_monthly 
where fiscal_year = 2020) as 'unique_products_2020', 
count(distinct(product_code)) as 'unique_products_2021',
round((abs((select count(distinct(product_code)) from fact_sales_monthly 
where fiscal_year = 2020)-((select count(distinct(product_code)) from fact_sales_monthly 
where fiscal_year = 2021)))/((select count(distinct(product_code)) from fact_sales_monthly 
where fiscal_year = 2020))) * 100,2) as 'percentage_chg'
from fact_sales_monthly 
where fiscal_year = 2021; 


/* 3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields, 
segment
product_count
*/

select segment, count(distinct product_code) as product_count
from dim_product
group by segment
order by product_count DESC;


/* 4. 4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields, 
segment
product_count_2020
product_count_2021
difference*/

WITH product_2020 AS (select dp.segment, count(distinct fsm.product_code) as product_count_2020
from dim_product dp, fact_sales_monthly fsm
where dp.product_code = fsm.product_code and fsm.fiscal_year = 2020
group by dp.segment
order by product_count_2020 DESC ),

product_2021 AS (select dp.segment, count(distinct dp.product_code) as product_count_2021
from dim_product dp, fact_sales_monthly fsm
where dp.product_code = fsm.product_code and fsm.fiscal_year = 2021
group by dp.segment)

select p1.segment, product_count_2020, product_count_2021, abs(product_count_2020-product_count_2021) as difference 
from  product_2020 p1, product_2021 p2
where p1.segment=p2.segment;


/* 5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost*/

with cost as (select m.product_code, p.product, m.manufacturing_cost
from fact_manufacturing_cost m, dim_product p
 where m.product_code = p.product_code)
 
 select * from cost
 where manufacturing_cost = (select min(manufacturing_cost) from fact_manufacturing_cost)
 or manufacturing_cost = (select max(manufacturing_cost) from fact_manufacturing_cost);

# alternate approach

select m.product_code, p.product, m.manufacturing_cost
from fact_manufacturing_cost m, dim_product p
 where m.product_code = p.product_code and 
 ((m.manufacturing_cost in (select min(manufacturing_cost) from fact_manufacturing_cost))
 or (m.manufacturing_cost in (select max(manufacturing_cost) from fact_manufacturing_cost)));


/* 6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage */

with disc as (select dc.customer_code, dc.customer, fid.pre_invoice_discount_pct from dim_customer dc, fact_pre_invoice_deductions fid
where (dc.customer_code = fid.customer_code) and (fid.fiscal_year = 2021) and (dc.market='India'))

select customer_code, customer, avg(pre_invoice_discount_pct) asaverage_discount_percentage
from disc
group by dc.customer_code, dc.customer
order by 3 DESC
limit 5;


/* 7. Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount */

SET sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));

with gross as (select month(fsm.date) as 'month_sales', year(date) as 'year_sales', (fsm.sold_quantity * fgp.gross_price) as sales_amount 
from fact_sales_monthly fsm, fact_gross_price fgp
where (fsm.product_code = fgp.product_code) and (fsm.customer_code in (select customer_code from dim_customer
where customer = 'Atliq Exclusive')) 
order by 1 asc)

select  month_sales as 'month', year_sales as 'year', sum(round(sales_amount)) as 'gross sales amount'
from gross g
group by month_sales
order by 1;


/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity
*/

with quarter_sold as ( select quarter(date) as quarter_sold_quantity, sold_quantity 
from fact_sales_monthly
where fiscal_year=2020
)

select quarter_sold_quantity as 'Quarter', sum(sold_quantity) as 'total_sold_quantity' 
from quarter_sold
group by quarter_sold_quantity
order by 2 desc;


/* 9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage
*/


with gross_sales as (SELECT channel, gross_price * sold_quantity as total_sales
FROM fact_gross_price fgp
JOIN fact_sales_monthly fsm ON fgp.product_code = fsm.product_code
JOIN dim_customer dc ON fsm.customer_code = dc.customer_code
where fgp.fiscal_year=2021),

channel_sales as (select channel, sum(total_sales) as sales   
from gross_sales
group by channel)

select channel, sales as gross_sales_mln, round(sales/(select sum(sales) from channel_sales) * 100,2) AS percentage
from channel_sales
order by 3 desc;



/*
10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order

*/

/* Joined the dim_product and fact_sales_monthly on product_code
	Select columns and calculate row column using partition on division
    filter using where on fiscal year
    store it as cte
    filter the rows from cte based on row column <=3
    */
with division_sales as (select dp.division, fsm.product_code, dp.product, sold_quantity, row_number() over (partition by dp.division order by sold_quantity desc ) as row_num
from fact_sales_monthly as fsm
join dim_product as dp
on fsm.product_code = dp.product_code
where fsm.fiscal_year=2021)

select division, product_code, product, sold_quantity, row_num as rank_order
from division_sales
where row_num<=3;



