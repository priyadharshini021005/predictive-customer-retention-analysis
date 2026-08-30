/*1. What is GRANT in SQL?

GRANT is used to give permissions (privileges) to a user on database objects like tables, views, etc.

Example permissions:

SELECT (read data)
INSERT (add data)
UPDATE (modify data)
DELETE (remove data)

*/

CREATE DATABASE luci;
DROP DATABASE luci;
USE luci;

CREATE TABLE employees (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    salary INT
);

INSERT INTO employees VALUES (1, 'Mani', 25000);
INSERT INTO employees VALUES (2, 'Kumar', 30000);

SELECT * FROM employees;

-- Create a User

CREATE USER 'root'@'localhost:3306' IDENTIFIED BY 'Priya@02';

-- Give SELECT permission

GRANT SELECT ON employees TO 'root'@'localhost:3306';

-- Give multiple permissions

GRANT SELECT, INSERT ON employees TO 'root'@'localhost:3306';

-- Give ALL permissions

GRANT ALL PRIVILEGES ON employees TO 'root'@'localhost:3306';

-- Apply changes

FLUSH PRIVILEGES;

/*What is REVOKE in SQL?

 * REVOKE is used to remove permissions from a user.
 
 */
 
 -- Remove SELECT permission

REVOKE SELECT ON employees FROM 'test_user'@'localhost';

-- Remove multiple permissions

REVOKE SELECT, INSERT ON employees FROM 'test_user'@'localhost';

-- Remove ALL permissions
REVOKE ALL PRIVILEGES
ON company.employees 
FROM 'test_user'@'localhost';

-- Check User Exists
SELECT user, host
FROM mysql.user;


DROP USER 'test_user'@'localhost';

-- Check Permissions

SHOW GRANTS FOR 'root'@'localhost:3306';


/*  Real-Time Scenario
            Company Example:

Admin gives SELECT access to employee → Only view data
Manager gets SELECT + UPDATE → Can view & edit
If employee leaves → Use REVOKE to remove access
*/