drop table if exists movie
CREATE TABLE movies (
    name       TEXT,
    rating     TEXT,           
    genre      TEXT,
    year       INTEGER,
    released   TEXT,
    score      NUMERIC(3,1),  
    votes      NUMERIC,
    director   TEXT,
    writer     TEXT,
    star       TEXT,
    country    TEXT,
    budget     NUMERIC,
    gross      NUMERIC,
    company    TEXT,
    runtime    NUMERIC        
);

select * from movies

-- Write a query that returns each genre's average ROI and number of movies.
-- ROI = (gross - budget) / budget * 100
-- Exclude rows where budget IS NULL or budget = 0.
-- Order by avg_roi DESC.
select genre, 
round(avg((gross - budget) * 100 /budget),2)  as avg_roi_percent,
count(* ) as total_movies
from movies 
where budget is not null 
and budget > 0
and gross is not null
group by genre
order by  avg_roi_percent desc;


-- Rank directors by total box-office profit (gross - budget).
-- Only include directors with at least 3 films.
-- Show total_profit, num_films, avg_profit_per_film.
-- Order by total_profit DESC.
select director,
    SUM(gross - budget) AS total_profit,
    COUNT(*)AS num_films,
    ROUND(AVG(gross - budget), 2)AS avg_profit_per_film
from movies
where budget IS NOT NULL
    AND gross IS NOT NULL
    AND budget > 0
    AND gross > 0
group by director 
having count(*) >= 3
order by total_profit desc;


-- Segment movies into IMDb score buckets using CASE WHEN:
--   '<5', '5-6', '6-7', '7-8', '8+'
-- For each bucket: avg_gross, avg_score, movie_count.
-- Order by avg_gross DESC.
select 
case 
 when score < 5 then '<5'
when score < 6 then '5-6'
when score <7 then '7-6'
when score <8 then '8-7'
else '8+'
end  as score_buckets,
round(avg(gross)) as avg_gross,
round (avg (score)) as avg_score,
count (*) as movie_count
from movies
where gross is not null
and score is not null
group by score_buckets
order by avg_score DESC;


-- Find movies that recouped less than 50% of their budget.
-- recovery_pct = gross / budget * 100
-- Exclude nulls/zeros in budget and gross.
-- Order by recovery_pct ASC (worst flops first).

select
name , year ,genre , budget , gross , director,
round(gross/budget* 100) as recovery_pct
from movies
order by recovery_pct ASC;


-- For each decade, calculate each company's total gross and its
-- percentage share of that decade's total box office.
-- Use FLOOR(year / 10) * 10 for decade.
-- Use SUM() OVER (PARTITION BY decade) for total.
-- Show only top 5 companies per decade
--decade | company | total_gross | market_share_pct
SELECT
    FLOOR(year / 10) * 10 AS decade,
    company,
    SUM(gross) AS total_gross,
    ROUND(SUM(gross) / SUM(SUM(gross)) OVER (PARTITION BY FLOOR(year / 10) * 10) * 100, 2) AS market_share_pct
FROM movies
WHERE gross IS NOT NULL AND company IS NOT NULL
GROUP BY FLOOR(year / 10) * 10, company
ORDER BY decade, total_gross DESC;

-- For each star (lead actor), calculate:
--   total_gross, avg_gross, num_films, avg_score
-- Only include stars with at least 5 films.
-- Order by total_gross DESC. Show top 20.
--star | total_gross | avg_gross | num_films | avg_score

select 
	star ,
	sum(gross) as total_gross,
	avg(gross) as avg_gross,
	avg(score) as avg_score,
	count(name ) as num_files
from movies
group by star
having count(name )>= 5
order by total_gross DESC
limit 20;


-- Compute total gross per year, then use LAG() to compare 
-- against the prior year.
-- yoy_growth_pct = (current - prior) / prior * 100
-- Use a CTE for the per-year totals.
--year | total_gross | prev_year_gross | yoy_growth_pct

select year ,
	sum(gross) as total_gross ,
 	 LAG(sum(gross)) OVER (ORDER BY year) AS prev_year_gross,
    ROUND((sum(gross) - LAG(sum(gross)) OVER (ORDER BY year)) 
        / LAG(sum(gross)) OVER (ORDER BY year) * 100, 2
    ) AS yoy_growth_pct
from movies
where gross is not null
group by year
order by year;



-- Count movies per (decade, genre).
-- Calculate each genre's % of that decade's total using a window function.
-- This shows whether e.g. Action is growing vs. Romance declining.
--decade | genre | movie_count | pct_of_decade_total
Select 
	FLOOR(year / 10) * 10 AS decade,
	genre,
	count (genre ) as movie_count ,
	ROUND(count(*) * 100.0 / sum(count(*)) over (partition by floor(year / 10) * 10), 2) AS pct_of_decade_total
from movies 
where genre is not null and year is not null
group by FLOOR(year / 10) * 10 , year, genre
order by year;


-- Bucket runtimes: '<90', '90-110', '110-130', '130-150', '150+'
-- For each bucket: avg_score, avg_gross, movie_count.
-- Which runtime wins on both metrics?
--runtime_bucket | avg_score | avg_gross | movie_count

select 
case 
	when runtime < 90 then '<90'
	when runtime < 110 then '90-110'
	when runtime < 130 then '110-130'
	when runtime < 150 then '130-150'
	else '150+' 
end as runtime_bucket,
round(avg(gross)) as avg_gross,
round(avg(score)) as avg_score,
count(*) as movies_count
from movies
where gross is not null and score is not null
group by runtime_bucket
order by avg_gross DESC ;

-- For each country, return only the single highest-grossing film.
-- Use RANK() OVER (PARTITION BY country ORDER BY gross DESC).
-- Filter where rank = 1.
-- country | name | gross | year
SELECT country, name, gross, year
FROM (
    SELECT country, name, gross, year,
           RANK() OVER (PARTITION BY country ORDER BY gross DESC) AS rnk
    FROM movies
    WHERE gross IS NOT NULL
) ranked
WHERE rnk = 1
ORDER BY gross DESC;


-- Per year (min 10 movies), show avg_budget, avg_gross, 
-- and the ratio avg_budget / avg_gross.
-- Order by year. This reveals if budgets are outpacing returns.
--year | avg_budget | avg_gross | budget_to_gross_ratio

select year,
	round(avg(budget) :: numeric ,2) as avg_bedget,
	round (avg(gross) :: numeric ,2) as avg_gross,
	round(avg(budget)/ avg(gross)) as budget_to_gross_ratio
from movies
where gross is not null and budget is not null
group by year
having count(*) >=10
order by  year;


-- For each MPAA rating (G, PG, PG-13, R, NC-17):
-- avg_gross, avg_score, total_movies, avg_budget, avg_roi.
-- Order by avg_gross DESC.
-- rating | avg_gross | avg_score | total_movies | avg_budget | avg_roi

select 
	rating ,
	round(avg(budget) :: numeric ,2) as avg_bedget,
	round (avg(gross) :: numeric ,2) as avg_gross,
	round(avg(score) :: numeric ,2) as avg_score,
	count(*) AS total_movies,
	round(avg((gross - budget) / nullif(budget, 0) * 100), 2) AS avg_roi
from movies
where gross is not null 
and score is not null
and budget is not null
group by rating 
order by avg_gross;


--select rating from movies 
--group by rating;

-- Group by (director, writer) pairs.
-- Show: num_collaborations, avg_score, avg_gross.
-- Only pairs with 2+ collaborations.
-- Order by avg_score DESC.
-- director | writer | num_collaborations | avg_score | avg_gross

select director, writer,
	count(*) as num_collaborations,
	round(avg(score) :: numeric ,2) as avg_score,
	round (avg(gross) :: numeric ,2) as avg_gross
from movies 
where gross is not null 
and score is not null
group by director, writer
having  count(*) >= 2
order by avg_score DESC;