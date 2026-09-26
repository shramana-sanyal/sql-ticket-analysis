-- 1. Ticket volume and priority mix by department
SELECT department, COUNT(*) AS total,
       SUM(CASE WHEN priority='high' THEN 1 ELSE 0 END) AS high,
       ROUND(100.0*SUM(CASE WHEN priority='high' THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_high
FROM tickets GROUP BY department ORDER BY total DESC;

-- 2. Most common tags (join + HAVING to drop the long tail)
SELECT t.tag, COUNT(*) AS tickets
FROM ticket_tags t JOIN tickets tk ON tk.ticket_id = t.ticket_id
GROUP BY t.tag HAVING COUNT(*) >= 100
ORDER BY tickets DESC LIMIT 15;

-- 3. Top 3 tags per department (CTE + RANK window function)
WITH tag_counts AS (
    SELECT tk.department, t.tag, COUNT(*) AS n
    FROM ticket_tags t JOIN tickets tk ON tk.ticket_id = t.ticket_id
    GROUP BY tk.department, t.tag HAVING COUNT(*) >= 20
), ranked AS (
    SELECT department, tag, n,
           RANK() OVER (PARTITION BY department ORDER BY n DESC) AS rank_in_dept
    FROM tag_counts
)
SELECT * FROM ranked WHERE rank_in_dept <= 3 ORDER BY department, rank_in_dept;

-- 4. Which tags concentrate in one department (correlated subquery)
WITH tag_dept AS (
    SELECT tk.department, t.tag, COUNT(*) AS n
    FROM ticket_tags t JOIN tickets tk ON tk.ticket_id = t.ticket_id
    GROUP BY tk.department, t.tag
), tag_total AS (
    SELECT tag, SUM(n) AS total FROM tag_dept GROUP BY tag HAVING SUM(n) >= 200
)
SELECT td.tag, td.department AS top_department,
       ROUND(100.0*td.n/tt.total,1) AS pct_in_top_dept
FROM tag_dept td JOIN tag_total tt ON tt.tag = td.tag
WHERE td.n = (SELECT MAX(n) FROM tag_dept x WHERE x.tag = td.tag)
ORDER BY pct_in_top_dept DESC LIMIT 15;

-- 5. Overall high-priority baseline
SELECT COUNT(*) AS total_tickets,
       ROUND(100.0*SUM(CASE WHEN priority='high' THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_high
FROM tickets;

-- 6. Which tags signal high priority
SELECT t.tag, COUNT(*) AS tickets,
       ROUND(100.0*SUM(CASE WHEN tk.priority='high' THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_high
FROM ticket_tags t JOIN tickets tk ON tk.ticket_id = t.ticket_id
GROUP BY t.tag HAVING COUNT(*) >= 200
ORDER BY pct_high DESC LIMIT 15;

-- 7. Department summary (ROW_NUMBER to pick one top tag each)
WITH dept_top_tag AS (
    SELECT tk.department, t.tag, COUNT(*) AS n,
           ROW_NUMBER() OVER (PARTITION BY tk.department ORDER BY COUNT(*) DESC) AS rn
    FROM ticket_tags t JOIN tickets tk ON tk.ticket_id = t.ticket_id
    WHERE t.tag NOT IN ('Tech Support','IT','Performance')
    GROUP BY tk.department, t.tag
)
SELECT tk.department, COUNT(*) AS tickets,
       ROUND(100.0*SUM(CASE WHEN tk.priority='high' THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_high,
       ROUND(AVG(tk.body_length)) AS avg_length, dt.tag AS top_tag
FROM tickets tk
LEFT JOIN dept_top_tag dt ON dt.department = tk.department AND dt.rn = 1
GROUP BY tk.department, dt.tag ORDER BY tickets DESC;