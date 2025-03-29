# Section A

# 🏎️ Running the Application 

To run the application, you need to use `docker-compose`. Follow the steps below to get it up and running:

Prerequisites
Make sure you have the following installed on your machine:

* [Docker](https://www.docker.com/get-started)
* [Docker Compose](https://docs.docker.com/compose/install/)

## Steps to Run the Application

1. Build and Start the Containers:

Use docker-compose to build and start the containers. This will set up all the necessary services defined in the docker-compose.yml file.

```bash
docker-compose up --build
```
The --build flag ensures that any changes to the Dockerfile are applied and the containers are rebuilt if necessary.
A simple SQL client will be available at http://localhost:8080 the credentials to access the databse could be found at docker-compose.yaml file.

2. Database Initialization:

Upon starting the containers, the MySQL database will be automatically initialized with the seed data provided in the exercise. This ensures that your database is populated with the required initial data.

3. Flyway Database Migration:

Flyway will run automatically and will create the necessary indexes for better query performance

4. Visualize the data

--Needs to create

5. Stopping the Application:

To stop the running containers and remove them, run:

```bash
docker-compose down
```

This command will stop the containers but keep your data volumes intact. If you want to remove volumes as well (e.g., to reset your environment), use:

```bash
docker-compose down --volumes
```

## Troubleshooting
 
* If you run into issues, you can check the logs for detailed information on what went wrong:

```bash
docker-compose logs
```

* To force a rebuild of the images (e.g., if there are code changes), run:

```
docker-compose up --build --force-recreate
```

# Exercise Resolution

## Before anything else

For this exercice all queries are evaluated based on the `Query Perfomance Table` defined bellow. Basically this table categorize query into four levels:

* 🔥 Perfect query - Optimized with minimal rows scanned, using indexes efficiently.
* ✅ Ok query - Uses indexes well but may have minor inefficiencies.
* ⚠️ Attention Query – Partial optimization but still scanning unnecessary rows.
* ❌ Bad Query – Full table scans, inefficient filtering, or missing indexes.

Each query will be analized using EXPLAIN. The minimum quality gate for queries is `Ok query`. 
 
| **Category**| **EXPLAIN Type**| **Index Usage (`key`)**|**Rows Scanned** _(Relative to Total)_| **Extra Column Insights**| **Example Query**|
|----------------------|---------------------|-------------------------|---------------------------------------|------------------------------------|--------------------|
| 🔥 **Perfect Query** |`const`, `eq_ref`, `system`|✅ Fully Indexed Lookup|**1:1 or less** (1 row scanned per record returned) | `Using index` (Fastest case)| `SELECT * FROM users WHERE id = 12345;`|Use **`PRIMARY KEY`** or **`UNIQUE`** indexes|
| ✅ **OK Query**|`ref`, `range`| ✅ Index used|**Up to 10:1** (10 rows scanned per 1 record returned)| `Using where`, Index scan | `SELECT * FROM orders WHERE order_date >= '2023-01-01';`|
| ⚠️ **Attention Query** | `index` (Full Index Scan) | ⚠️ Index used, but inefficient | **11:1 to 20:1** (11-20 rows scanned per 1 record returned) | `Using temporary`, `Using filesort` | `SELECT * FROM products ORDER BY price DESC;` | 
| ❌ **Bad Query** | `ALL` (Full Table Scan) | ❌ No index used| **Over 20:1** _(More than 20 rows scanned per 1 record returned)_ | `Using temporary`, `Using filesort`, `NULL key` | `SELECT * FROM orders WHERE YEAR(order_date) = 2023;` | 

Based on that, we'll make decisions about indices creation. Of course, we need to keep in mind that for a real application too many indexes can hurt the perfomance, to avoid the "index bloat" in real application we need to have a clear database observability plan to check the queries perfomance, it could be achieved with thrird-party tools as New Relic or even by a process that relies in queries in database.

## Exercise 1 - Display the name (first_name and last_name) and department ID of all employees in departments 30 or 100 in ascending order.

### Solution

```sql
CREATE INDEX EMP_DEPT_NAME_IX ON employees (DEPARTMENT_ID, FIRST_NAME, LAST_NAME);

SELECT e.FIRST_NAME, e.LAST_NAME, e.DEPARTMENT_ID FROM employees e
WHERE e.DEPARTMENT_ID IN (30,100)
ORDER BY e.FIRST_NAME ASC, e.LAST_NAME ASC;

EXPLAIN SELECT e.FIRST_NAME, e.LAST_NAME, e.DEPARTMENT_ID FROM employees e
WHERE e.DEPARTMENT_ID IN (30,100)
ORDER BY e.FIRST_NAME ASC, e.LAST_NAME ASC;
```

### Result

12 rows were returned

**EXPLAIN Analysis:**

| id  | select_type | table | partitions | type  | possible_keys              | key            | key_len | ref  | rows | filtered | Extra                                       |
|-----|-------------|-------|------------|-------|----------------------------|----------------|---------|------|------|----------|---------------------------------------------|
| 1| SIMPLE | e | NULL| range| EMP_DEPARTMENT_IX, EMP_DEPT_NAME_IX | EMP_DEPT_NAME_IX | 3 | NULL | 28 | 100.00 | Using where; Using index; Using filesort|

This query was classified as **OK Query** we have a potential optimization due query performs a filesort.

---
**NOTE**

For exercises 2 and 3, I decided to add a computed column to the employee table. This approach offers several advantages as:
* Avoids repeated calculations
* Simplifies queries and improves readability 
* Allows indexing at the database level for better performance.

However, this approach may not be ideal when the table experiences frequent INSERT or UPDATE operations, or if the formula is complex and changes frequently.


```
ALTER TABLE employees ADD COLUMN ACTUAL_SALARY DECIMAL(10,2) 
GENERATED ALWAYS AS (SALARY + (SALARY * COMMISSION_PCT)) STORED;
```
---

### Exercise 2 - Find the manager ID and the salary of the lowest-paid employee for that manager.

### Solution

```sql
CREATE INDEX EMP_MANAGER_ACTUAL_SALARY_IX ON employees(MANAGER_ID, ACTUAL_SALARY);

SELECT e.MANAGER_ID, e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME, e.ACTUAL_SALARY 
FROM employees e 
JOIN(
    SELECT employees.MANAGER_ID, MIN(employees.ACTUAL_SALARY) AS LOWEST_SALARY 
    FROM employees 
    GROUP BY employees.MANAGER_ID 
    ORDER BY NULL
) lowest_paid 
ON e.MANAGER_ID = lowest_paid.MANAGER_ID AND e.ACTUAL_SALARY = lowest_paid.LOWEST_SALARY

EXPLAIN SELECT e.MANAGER_ID, e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME, e.ACTUAL_SALARY 
FROM employees e 
JOIN(
    SELECT employees.MANAGER_ID, MIN(employees.ACTUAL_SALARY) AS LOWEST_SALARY 
    FROM employees 
    GROUP BY employees.MANAGER_ID 
    ORDER BY NULL
) lowest_paid 
ON e.MANAGER_ID = lowest_paid.MANAGER_ID AND e.ACTUAL_SALARY = lowest_paid.LOWEST_SALARY
```

### Result

19 rows were returned

**EXPLAIN Analysis:**

| id  | select_type | table        | partitions | type  | possible_keys                               | key                    | key_len | ref                                    | rows | filtered | Extra                          |
|-----|-------------|--------------|------------|-------|---------------------------------------------|------------------------|---------|----------------------------------------|------|----------|--------------------------------|
| 1   | PRIMARY     | <derived2>   | NULL       | ALL   | NULL                                        | NULL                   | NULL    | NULL                                   | 18   | 100.00   | Using where                    |
| 1   | PRIMARY     | e            | NULL       | ref   | EMP_MANAGER_IX, EMP_MANAGER_SALARY_IX, EMP_MANAGER_ACTUAL_SALARY_IX | EMP_MANAGER_ACTUAL_SALARY_IX | 10      | lowest_paid.MANAGER_ID,lowest_paid.LOWEST_SALARY | 1    | 100.00   | NULL                           |
| 2   | DERIVED     | employees    | NULL       | range | EMP_MANAGER_IX, EMP_MANAGER_SALARY_IX, EMP_MANAGER_ACTUAL_SALARY_IX | EMP_MANAGER_ACTUAL_SALARY_IX | 10      | NULL                                   | 18   | 100.00   | Using index for group-by       |


This query was classified as **OK Query**


### Exercise 3 - find the name (first_name and last_name) and the salary of the employees who earn more than the employee whose last name is Bell.

### Solution

```sql
CREATE INDEX EMP_LAST_NAME_ACTUAL_SALARY_IX ON employees(LAST_NAME, ACTUAL_SALARY);

SELECT e1.FIRST_NAME, e1.LAST_NAME, e1.ACTUAL_SALARY
FROM employees e1
JOIN (SELECT MAX(ACTUAL_SALARY) AS MAX_SALARY FROM employees WHERE LAST_NAME = 'Bell') e2
ON e1.ACTUAL_SALARY > e2.MAX_SALARY

EXPLAIN SELECT e1.FIRST_NAME, e1.LAST_NAME, e1.ACTUAL_SALARY
FROM employees e1
JOIN (SELECT MAX(ACTUAL_SALARY) AS MAX_SALARY FROM employees WHERE LAST_NAME = 'Bell') e2
ON e1.ACTUAL_SALARY > e2.MAX_SALARY
```
### Result

64 rows were returned

**EXPLAIN Analysis:**

| id  | select_type | table      | partitions | type   | possible_keys | key                            | key_len | ref  | rows  | filtered | Extra                        |
|-----|-------------|------------|------------|--------|----------------|--------------------------------|---------|------|-------|----------|------------------------------|
| 1   | PRIMARY     | <derived2> | NULL       | system | NULL           | NULL                           | NULL    | NULL | 1     | 100.00   | NULL                         |
| 1   | PRIMARY     | e1         | NULL       | index  | NULL           | EMP_FIRST_NAME_LAST_NAME_ACTUAL_SALARY_IX | 56      | NULL | 107   | 33.33    | Using where; Using index     |
| 2   | DERIVED     | NULL       | NULL       | NULL   | NULL           | NULL                           | NULL    | NULL | NULL  | NULL     | Select tables optimized away |


This query was classified as **OK Query**

#### Exercise 4 - find the name (first_name and last_name), job, department ID and name of all employees that work in London

---
**NOTE**
I noticed that this table had some interesting data in the city field. For example, we have "South San Francisco," which suggests that we might encounter similar entries in the future, such as "South London." Additionally, the table includes postal codes instead of city names in some cases. The query was developed with these scenarios in mind.

---

```sql
SELECT CONCAT(e.FIRST_NAME, ' ', e.LAST_NAME) AS full_name, j.JOB_TITLE, d.DEPARTMENT_ID, d.DEPARTMENT_NAME 
FROM employees e 
LEFT JOIN jobs j ON j.job_id = e.job_id 
LEFT JOIN departments d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID 
LEFT JOIN locations l ON l.LOCATION_ID = d.LOCATION_ID 
WHERE l.CITY LIKE 'London%' 
OR INSTR(l.CITY, 'London') > 0 
OR Trim(l.CITY) REGEXP '^(E|EC|N|NW|SE|SW|W|WC)[0-9R][0-9A-Z]?\\s?[0-9][A-Z]{2}$'

EXPLAIN SELECT CONCAT(e.FIRST_NAME, ' ', e.LAST_NAME) AS full_name, j.JOB_TITLE, d.DEPARTMENT_ID, d.DEPARTMENT_NAME 
FROM employees e 
LEFT JOIN jobs j ON j.job_id = e.job_id 
LEFT JOIN departments d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID 
LEFT JOIN locations l ON l.LOCATION_ID = d.LOCATION_ID 
WHERE l.CITY LIKE 'London%' 
OR INSTR(l.CITY, 'London') > 0 
OR Trim(l.CITY) REGEXP '^(E|EC|N|NW|SE|SW|W|WC)[0-9R][0-9A-Z]?\\s?[0-9][A-Z]{2}$'
```
### Result 

1 row was returned

**EXPLAIN Analysis:**

| id  | select_type | table | partitions | type  | possible_keys                    | key      | key_len | ref                        | rows | filtered | Extra      |
|-----|-------------|-------|------------|-------|-----------------------------------|----------|---------|----------------------------|------|----------|------------|
| 1   | SIMPLE      | e     | NULL       | ALL   | EMP_DEPARTMENT_IX, EMP_DEPT_NAME_IX | NULL     | NULL    | NULL                       | 107  | 100.00   | NULL       |
| 1   | SIMPLE      | j     | NULL       | eq_ref| PRIMARY                           | PRIMARY  | 12      | company.e.JOB_ID           | 1    | 100.00   | NULL       |
| 1   | SIMPLE      | d     | NULL       | eq_ref| PRIMARY, DEPT_LOCATION_IX         | PRIMARY  | 2       | company.e.DEPARTMENT_ID     | 1    | 100.00   | NULL       |
| 1   | SIMPLE      | l     | NULL       | eq_ref| PRIMARY, LOC_CITY_IX              | PRIMARY  | 2       | company.d.LOCATION_ID       | 1    | 100.00   | Using where|


This query was classified as **OK Query**

### Exercise 5 - get the department name and number of employees in the department

```sql
CREATE INDEX DEP_NAME_IX ON departments(DEPARTMENT_NAME);

SELECT COALESCE(d.DEPARTMENT_NAME, 'No Department') AS DEPARTMENT_NAME, COUNT(e.EMPLOYEE_ID) AS COUNT
FROM employees e
LEFT JOIN departments d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID
GROUP BY COALESCE(d.DEPARTMENT_NAME, 'No Department')
ORDER BY NULL;

EXPLAIN SELECT COALESCE(d.DEPARTMENT_NAME, 'No Department') AS DEPARTMENT_NAME, COUNT(e.EMPLOYEE_ID) AS COUNT
FROM employees e
LEFT JOIN departments d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID
GROUP BY COALESCE(d.DEPARTMENT_NAME, 'No Department')
ORDER BY NULL;
```

### Result 

12 rows were returned

**EXPLAIN Analysis:**

| id  | select_type | table | partitions | type  | possible_keys        | key       | key_len | ref                      | rows | filtered | Extra          |
|-----|-------------|-------|------------|-------|----------------------|-----------|---------|--------------------------|------|----------|----------------|
| 1| SIMPLE |e| NULL|ALL|NULL|NULL|NULL| NULL|107|100.00|Using temporary |
| 1 |SIMPLE|d|NULL |eq_ref| PRIMARY, DEP_NAME_IX |PRIMARY|2|company.e.DEPARTMENT_ID |1 |100.00| NULL|

This query was classified as **OK Query**
