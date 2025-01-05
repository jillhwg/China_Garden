select * from [dbo.cleaned_table]


-- Clean and Check Data
exec sp_rename 'dbo.final.Name0', 'Name', 'COLUMN'


select
  sum(DishTotal)
from dbo.[dbo.cleaned_table]
where Date = '2020-05-14'
-- $631, 40 orders


select
  sum(DishTotal)
from dbo.[dbo.cleaned_table]
where Time not between '11:00:00' and '22:30:00'
-- $24.43, 5 orders

select
	count(distinct invno)
from dbo.[dbo.cleaned_table]
where Date = '2020-05-06'
-- $13, 1 order

select
	sum(dishtotal)
from dbo.[dbo.cleaned_table]
where Date is null
-- $8.5, 1 order

select
	count(distinct invno)
from dbo.[dbo.cleaned_table]
where Date is not null and time between '11:00:00' and '22:30:00' and Date > '2020-05-06'
-- $13,187.06 | 668 orders | Matches Dashboard KPI


-- New table that matches dashboard
select *
into final
from dbo.[dbo.cleaned_table]
where Date is not null and time between '11:00:00' and '22:30:00' and Date > '2020-05-06'


-- Renumber all the categories
select *
from dbo.final
where category not in (110, 120, 130, 150, 160, 170, 180, 190, 195,200,202,204,206,208,210,212,214,216,218,220,222,224,226)
order by Invno, OrderSeq
--and price < 4

select distinct	category
from dbo.final
order by category


update dbo.final
set category = 120
where category = 235




--- REVENUE ANALYSIS ---
-- Total Revenue
select
  sum(DishTotal) as Total_Sales
from dbo.final


-- AOV per day
select
  Date,
  round(avg(OrderTotal),2) as AOV
from (
    select
      Date,
      Invno,
      sum(DishTotal) as OrderTotal
    from dbo.final
    group by Date, Invno
) as OrderTotals
group by Date
order by Date asc;


-- Notable Changes in Revenue
select
  Date,
  day_of_the_week,
  round(sum(DishTotal),2) Sales
from dbo.final
group by Date, day_of_the_week
order by Date


--- ORDER TRENDS
-- Total Orders per Day
select
  Date,
  count(distinct Invno) as NumOrders
from dbo.final
group by Date
order by Date asc;

-- Average of the week
select 
	avg(total_invno) avg_num_orders
from(
	select
		Date,
		count(distinct Invno) total_invno
	from dbo.final
	group by Date
) orders


-- Busiest Day of the Week + Percentages of Total
select
	date,
	day_of_the_week,
	day_orders,
	round((cast(day_orders as float) /cast(total_orders as float)),2) as percentage_of_total
from(
	select 
		date,
		day_of_the_week,
		count(distinct invno) as day_orders,
		(select count(distinct invno) from dbo.no_outliers) as total_orders
	from dbo.final
	group by date, Day_of_the_week
) sub
order by percentage_of_total desc, day_orders desc;


--- DISH TRENDS
-- Top 5 dishes
select top 5
  ItemNo,
  Name,
  count(*) as item_count
from dbo.final
group by ItemNo, Name
order by item_count desc


-- Worst performing dishes
select top 5
  ItemNo,
  Name,
  count(*) as item_count
from dbo.final
where Price > 3 
group by ItemNo, Name
order by item_count, itemno asc


-- Top Dish by the Day (need to redo with rank)
select top 5
  Date,
  Name,
  count(*) as item_count
from dbo.final
where Price > 3
group by Date, ItemNo, Name
order by item_count desc


-- Top Dish by Day of the week
with most_popular_dish as(
  select
    day_of_the_week,
    Name,
    count(*) as item_count,
    dense_rank() over(partition by day_of_the_week order by count(*) desc) as rank
  from dbo.final
  where Price > 3
  group by day_of_the_week, Name
)

select
  day_of_the_week,
  Name,
  item_count
from most_popular_dish
where rank = 1
order by day_of_the_week;

--- ORDER FREQUENCY
-- Lunch + Dinner percentage Total
-- How to distinguish lunch and dinner combos from the rest
-- Name would start with an “L#” or “C#” or the category = 208 + 217
-- Select all Dinner Combos
select *
from dbo.final
where name like 'C%' and substring(name,2,1) between '0' and '9';
-- Dinner combos (420 total)

select *
from dbo.final
where name like 'L%' and substring(name,2,1) between '0' and '9';
-- Lunch combos (125 total)

-- All the lunch combo modification will be changed from 208 to 209
select *
from `argon-system-414015.chinese_restaurant.one_week`
where category = 208 and name like 'w%';

-- Some dinner combo mods were also used during lunch time
update `argon-system-414015.chinese_restaurant.one_week`
set Category = 209
where category = 208 and name like 'w%' and Time between '11:00:00' and '15:00:00';

-- Now check all the dinner combo mods
select *
from `argon-system-414015.chinese_restaurant.one_week`
where name like 'w%' and Time between '15:00:00' and '23:00:00';


-- By date, days of the week, and percent of combos in total
select 
  Date,
  count(case when category = 222 then 1 end) as lunch_combos,
  count(case when category = 224 then 1 end) as dinner_combos,
  count(case when category not between 99 and 196 then 1 end) as total_orders
from dbo.final
group by Date


-- By total
select
count(distinct Invno) as total_orders,
count(distinct case
  when Time between '11:00:00.000' and '15:00:00.000' then Invno end) as lunch_order,
count(distinct case
  when Time between '15:00:00.000' and '23:00:00.000' then Invno end) as dinner_order,
count(distinct case
  when Time between '11:00:00.000' and '15:00:00.000' then Invno end) / count(distinct Invno) as lunch_portion,
count(distinct case
  when Time between '15:00:00.000' and '23:00:00.000' then Invno end) / count(distinct Invno) as dinner_portion
from dbo.final
where Time between '11:00:00.000' and '23:00:00.000';

-- Count + Percentage by Day
select
	date,
	total_orders,
	lunch_order,
	dinner_order,
	round(convert(float, lunch_order) / total_orders, 2) as lunch_portion,
	round(convert(float, dinner_order) / total_orders, 2) as dinner_portion
from(
		select
		date,
		count(distinct Invno) as total_orders,
		count(distinct case
		  when Time between '11:00:00.000' and '15:00:00.000' then Invno end) as lunch_order,
		count(distinct case
		  when Time between '15:00:00.000' and '23:00:00.000' then Invno end) as dinner_order
		from dbo.no_outliers
		group by date
) sub

-- Count by Day of the Week
select 
  day_of_the_week,
  count(case when category = 222 then 1 end) as lunch,
  count(case when category = 224 then 1 end) as dinner,
  count(case when category not between 99 and 196 then 1 end) as total_orders,
  round(
    count(case when category = 222 then 1 end) * 100 / count(case when category not between 99 and 196 then 1 end),2) as lunch_percent,
  round(count(case when category = 224 then 1 end) * 100 / count(case when category not between 99 and 196 then 1 end),2) as dinner_percent
from dbo.final
group by day_of_the_week
order by total_orders desc


--- MENU ANALYSIS
-- Top Performing Categories
-- The original data does not have any fields for the category names so I created a separate table with the category number and names to join to this dataset.
-- Create category table
create table categories (
	category int,
	category_name nvarchar(50)
)

-- Add Values
insert into dbo.categories (category, category_name)
values 
	(100, 'Rice mod'),
	(110, 'Lunch mod'),
	(115, 'Idk mod'),
	(120, 'Dinner mod'),
	(130, 'Chefs Special mod'),
	(140, 'Reg Order mod'),
	(150, 'Add Sauce mod'),
	(160, 'Add Meat mod'),
	(170, 'Add Veggies mod'),
	(180, 'Add Fried Rice mod'),
	(190, 'Specials mod'),
	(195, 'Cancelled'),
	(200, 'Appetizers'),
	(202, 'Soups'),
	(204, 'Specials + mods'),
	(206, 'Fried Rice/Lo Mein'),
	(208, 'Reg Chk/Pork'),
	(210, 'Reg Beef/Shr'),
	(212, 'Egg Foo/Moo Shu/Sns'),
	(214, 'Chop Suey/Chow Mein'),
	(216, 'Veggies/Diet'),
	(218, 'Mei Fun'),
	(220, 'Sodas/Crisp/Rice'),
	(222, 'Lunch'),
	(224, 'Dinner'),
	(226, 'Chefs Special')



select
  cat.category,
  cat.category_name,
  round(sum(DishTotal),2) as total_revenue
from dbo.final week
join dbo.categories cat
  on week.category = cat.category
group by cat.category, cat.category_name
order by total_revenue desc


-- Potential menu pairings that are often ordered together but not in combos. This could be an opportunity to create new combos.
/*
	logic steps
	1. self join tables
	2. group by invoice number
	3. separate by items one for each table
	4. compare the two items, make sure they are different ordersequence numbers (order 1 item 1, order 1 item 2)
	5. make unique pairs for each order item combination
	6. go through all the other invoices the same way and count the number of unique pairs
*/
with no_mods as(
  select *
  from dbo.final
  where price > 3
)

select
  table1.name as item1,
  table2.name as item2,
  count(*) as pair_count
from no_mods as table1
inner join no_mods as table2 
  on table1.invno = table2.invno
--and table1.name <> table2.name
where table1.name < table2.name
group by table1.name, table2.name
order by pair_count desc