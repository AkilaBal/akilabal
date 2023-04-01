/*you added a subquery to the FROM statement and selected the stages where the number of average goals 
in a stage exceeded the overall average number of goals in the 2012/2013 match season. In this final step, 
you will add a subquery in SELECT to compare the average number of goals scored in each stage to the total.*/



select * from dbo.match;

/*In this next step, you will turn the main query into a subquery to extract a list of stages where the average home goals 
in a stage is higher than the overall average
for home goals in a match.*/

/* you created a data set listing the average home and away goals in each match stage of the 2012/2013 match season.*/

--1. compare overall average goal to average goal for each stage for season  2012/2013


SELECT m.stage,
       Avg(m.home_team_goal + m.away_team_goal) AS avg_goals,
       Round((SELECT Avg (home_team_goal + away_team_goal)
              FROM   dbo.match
              WHERE  season = '2012/2013'), 2)  AS overall
FROM   dbo.match AS m
WHERE  season = '2012/2013'
GROUP  BY m.stage 

--2. compare the average number of goals scored in each stage to the total.ilter the main query for stages where the average goals equals or
--exceeds the overall average in 2012/2013.

SELECT 
	-- Select the stage and average goals from s
	stage,
    ROUND(avg_goals,2) AS avg_goal,
    -- Select the overall average for 2012/2013
    (select avg(home_team_goal + home_team_goal) from match WHERE season = '2012/2013') AS overall_avg
FROM 
	-- Select the stage and average goals in 2012/2013 from match
	(SELECT
		 stage,
         avg(home_team_goal + home_team_goal) AS avg_goals
	 FROM match
	 WHERE season = '2012/2013'
	 GROUP BY stage) AS s
WHERE 
	-- Filter the main query using the subquery
	s.avg_goals >= (SELECT avg(home_team_goal + home_team_goal) 
                    FROM dbo.match WHERE season = '2012/2013');



--3.examine matches with scores that are extreme outliers for each country -- above 3 times the average score!

SELECT country_id,
       date,
       home_team_goal,
       away_team_goal
FROM   dbo.match AS main
WHERE  ( home_team_goal + away_team_goal ) > Round((SELECT Avg(home_team_goal +
                                                               away_team_goal)
                                                    FROM   dbo.match AS sub
                                                    WHERE main.country_id = sub.country_id), 2) * 3 

-- 4. what was the highest scoring match for each country, in each season?
-- need to check the answer

SELECT country_id,
       season,
       date,
       home_team_goal,
       away_team_goal
FROM   dbo.match AS main
WHERE  ( home_team_goal + away_team_goal ) = (SELECT Max(home_team_goal +
                                                         away_team_goal)
                                              FROM   dbo.match AS sub
                                              WHERE
       main.country_id = sub.country_id
       AND main.season = sub.season) 

-- 5. How does each month total goals differ from average monthly goals of goals scored

SELECT Datepart(month, date)                   AS month_name,
       Sum(home_team_goal + away_team_goal)    AS total_goals,
       Sum(home_team_goal + away_team_goal) - (SELECT Avg(goals)
                                               FROM
       (SELECT Datepart(month, date)
               AS month_name,
               Sum(home_team_goal +
                   away_team_goal) AS
               goals
        FROM   dbo.match
        GROUP  BY Datepart(month, date)) AS x) AS avg_diff
FROM   dbo.match AS m
GROUP  BY Datepart(month, date); 

-- 6.What's the average number of matches per season where a team scored 5 or more goals? How does this differ by country?

SELECT c.NAME  AS country,
       Avg(outer_s.matches) AS avg_seasonal_high_scores
FROM   country AS c
       LEFT JOIN (SELECT country_id,
                         season,
                         Count(id) AS matches
                  FROM   (SELECT country_id,
                                 season,
                                 id
                          FROM   dbo.match
                          WHERE  home_team_goal > 5
                                  OR away_team_goal > 5) AS inner_sub
                  GROUP  BY country_id,
                            season) AS outer_s
              ON c.id = outer_s.country_id
GROUP  BY c.NAME; 


--7.get both the home and away team names into one final query result?

SELECT
    m.date,
    (SELECT team_long_name
     FROM team AS t
     WHERE t.team_api_id = m.home_team_api_id) AS hometeam,
    -- Connect the team to the match table
    (SELECT team_long_name
     FROM team AS t
     WHERE t.team_api_id = m.away_team_api_id) AS awayteam,
    -- Select home and away goals
     m.home_team_goal,
     m.away_team_goal
FROM match AS m;



-- same query with cte

WITH home AS (
  SELECT m.id, m.date, 
  		 t.team_long_name AS hometeam, m.home_team_goal
  FROM match AS m
  LEFT JOIN team AS t 
  ON m.home_team_api_id = t.team_api_id),
-- Declare and set up the away CTE
 away as (
  SELECT m.id, m.date, 
  		 t.team_long_name AS awayteam, m.away_team_goal
  FROM match AS m
  LEFT JOIN team AS t 
  ON m.away_team_api_id = t.team_api_id)
-- Select date, home_goal, and away_goal
SELECT 
	home.date,
    home.hometeam,
    away.awayteam,
    home.home_team_goal,
    away.away_team_goal
-- Join away and home on the id column
FROM home
INNER JOIN away
ON home.id = away.id;


-- 8. How many goals were stored in each match and how did that compare to the seasons average

select date , (home_team_goal + away_team_goal) as goals,
avg(home_team_goal + away_team_goal) over (partition by season ) as season_avg
from dbo.Match

-- 9. calculate the average number home and away goals scored Legia Warszawa, and their opponents, partitioned by the month in each season.


SELECT 
	date,
	season,
	home_team_goal,
	away_team_goal,
	CASE WHEN home_team_api_id = 8673 THEN 'home' 
         ELSE 'away' END AS warsaw_location,
	-- Calculate average goals partitioned by season and month
    avg(home_team_goal) over(partition by season , 
         	datepart(month , date)) AS season_mo_home,
    avg(away_team_goal) over(partition by season, 
            datepart(month , date)) AS season_mo_away
FROM match
WHERE 
	home_team_api_id = 8673
    OR away_team_api_id = 8673
ORDER BY (home_team_goal + away_team_goal) DESC;


--10.	calculating the running total of goals scored by the FC Utrecht when they were the home team during the 2011/2012 season. 
--Do they score more goals at the end of the season as the home or away team?

SELECT 
	date,
	home_team_goal,
	away_team_goal,
    -- Create a running total and running average of home goals
    sum(home_team_goal) over(ORDER BY date
         ROWS BETWEEN unbounded preceding AND current row) AS running_total,
    avg(home_team_goal) over(ORDER BY date 
         ROWS BETWEEN unbounded preceding AND current row) AS running_avg
FROM match
WHERE 
	home_team_api_id = 9908 
	AND season = '2011/2012';

-- 11. generate a list of matches in which Manchester United was defeated during the 2014/2015 English Premier League season.
-- uilding the query to extract all matches played by Manchester United in the 2014/2015 season. how badly did Manchester United lose in each match?

-- Set up the home team CTE
with home as (
  SELECT m.id, t.team_long_name,
	  CASE WHEN m.home_team_goal > m.away_team_goal THEN 'MU Win'
		   WHEN m.home_team_goal < m.away_team_goal THEN 'MU Loss' 
  		   ELSE 'Tie' END AS outcome
  FROM match AS m
  LEFT JOIN team AS t ON m.home_team_api_id = t.team_api_id),
-- Set up the away team CTE
away as (
  SELECT m.id, t.team_long_name,
	  CASE WHEN m.home_team_goal > m.away_team_goal THEN 'MU Win'
		   WHEN m.home_team_goal < m.away_team_goal THEN 'MU Loss' 
  		   ELSE 'Tie' END AS outcome
  FROM match AS m
  LEFT JOIN team AS t ON m.away_team_api_id = t.team_api_id)
-- Select team names, the date and goals
SELECT DISTINCT
    m.date,
    home.team_long_name AS home_team,
    away.team_long_name AS away_team,
    m.home_team_goal,
    m.away_team_goal,
	rank() over(order by cast(ABS(home_team_goal - away_team_goal) as bigint) desc) as match_rank -- error
-- Join the CTEs onto the match table
FROM match AS m
left JOIN home ON m.id = home.id
left JOIN away ON m.id = away.id
WHERE m.season = '2014/2015'
      AND (home.team_long_name = 'Manchester United' 
           OR away.team_long_name = 'Manchester United');