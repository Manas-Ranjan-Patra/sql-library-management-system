select * from books;
select * from branch;
select * from employees;
select * from issued_status;
select * from members;
select * from return_status;

set sql_safe_updates = 0;

-- 1.CRUD Operations

-- Task 1. Create a New Book Record -- "978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.')"

insert into books
values('978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.0, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.');

-- Task 2: Update an Existing Member's Address

UPDATE members 
SET 
    member_address = '125 Main St'
WHERE
    member_id = 'C101';

-- Task 3: Delete a Record from the Issued Status Table -- Objective: Delete the record with issued_id = 'IS121' from the issued_status table.

DELETE FROM issued_status 
WHERE
    issued_id = 'IS121';

-- Task 4: Retrieve All Books Issued by a Specific Employee -- Objective: Select all books issued by the employee with emp_id = 'E101'.

SELECT DISTINCT
    issued_book_name
FROM
    issued_status
WHERE
    issued_emp_id = 'E101';

-- Task 5: List Members Who Have Issued More Than One Book -- Objective: Use GROUP BY to find members who have issued more than one book.

SELECT 
    issued_member_id, COUNT(*)
FROM
    issued_status
GROUP BY issued_member_id
HAVING COUNT(*) > 1; 

-- 2. CTAS (Create Table As Select)

-- Task 6: Create Summary Tables: Used CTAS to generate new tables based on query results - each book and total book_issued_cnt

CREATE TABLE summary_table AS SELECT book_title, COUNT(issued_id) total_issue_cnt
FROM
    books JOIN issued_status 
    ON books.isbn = issued_status.issued_book_isbn
GROUP BY book_title;

SELECT * FROM summary_table;

-- 3. Data Analysis & Findings

-- Task 7. Retrieve All Books in a Specific Category:

SELECT *
FROM books
WHERE
    category = 'Classic';
    
-- Task 8: Find Total Rental Income by Category:

select category, sum(rental_price), count(*) issued_count
FROM
    books JOIN issued_status 
    ON books.isbn = issued_status.issued_book_isbn
GROUP BY category;

-- Task-9: List Members Who Registered in the Last 180 Days:

SELECT *
FROM members
WHERE
    reg_date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY);

-- Task-10: List Employees with Their Branch Manager's Name and their branch details:

SELECT 
    e1.emp_id, e1.emp_name, e2.emp_name AS mang_name, b.*
FROM
    employees e1
        JOIN
    branch b ON e1.branch_id = b.branch_id
        JOIN
    employees e2 ON e2.emp_id = b.manager_id;

-- Task 11. Create a Table of Books with Rental Price Above a Certain Threshold:

CREATE TABLE expensive_book AS 
SELECT * FROM books
WHERE
    rental_price > 7;

-- Task 12: Retrieve the List of Books Not Yet Returned

SELECT DISTINCT
    issued_book_name
FROM
    issued_status
        LEFT JOIN
    return_status ON return_status.issued_id = issued_status.issued_id
WHERE
    return_id IS NULL;
    
-- Task 13: Identify Members with Overdue Books Write a query to identify members who have overdue books (assume a 30-day return period). 
-- Display the member's_id, member's name, book title, issue date, and days overdue.

SELECT 
    ist.issued_member_id,
    m.member_name,
    ist.issued_book_name,
    DATEDIFF(CURRENT_DATE, STR_TO_DATE(issued_date, '%Y-%m-%d')) AS over_due
FROM
    issued_status ist
        JOIN
    members m ON ist.issued_member_id = m.member_id
        LEFT JOIN
    return_status rs ON ist.issued_id = rs.issued_id
WHERE
    return_date IS NULL
	AND DATEDIFF(CURRENT_DATE, STR_TO_DATE(issued_date, '%Y-%m-%d')) > 30;

-- Task 14: Update Book Status on Return
-- Write a query to update the status of books in the books table to "Yes" when they are returned (based on entries in the return_status table).

DELIMITER $$

create procedure book_status_update(IN p_return_id varchar(20), IN p_issued_id varchar(15), IN p_book_quality varchar(15))

BEGIN
	DECLARE v_isbn varchar(20);
    
	insert into return_status(return_id, issued_id, return_date, book_quality)
    values(p_return_id,p_issued_id, current_date,p_book_quality);
    
	select issued_book_isbn into v_isbn from issued_status
	where issued_id = p_issued_id;
    
	UPDATE books 
	SET 
		status = 'yes'
	WHERE
		isbn = v_isbn;
END $$

DELIMITER ;

call sql_project_02.book_status_update('RS120', 'IS128', 'good');

-- Task 15: Branch Performance Report
-- Create a query that generates a performance report for each branch, showing the number of books issued,
-- the number of books returned, and the total revenue generated from book rentals.

CREATE TABLE branch_report AS
SELECT 
    e.branch_id,
    COUNT(ist.issued_id) no_of_book_issued,
    COUNT(rs.return_id) no_of_book_return,
    SUM(b.rental_price) total_rent
FROM
    employees e
        JOIN
    issued_status ist ON e.emp_id = ist.issued_emp_id
        JOIN
    books b ON b.isbn = ist.issued_book_isbn
        LEFT JOIN
    return_status rs ON ist.issued_id = rs.issued_id
GROUP BY e.branch_id; 

-- Task 16: CTAS: Create a Table of Active Members
-- Use the CREATE TABLE AS (CTAS) statement to create a new table active_members containing members who have issued at least one book in the last 2 months.

CREATE TABLE CTAS AS
SELECT 
    *
FROM
    members
WHERE
    member_id IN(SELECT DISTINCT
						issued_member_id
					FROM
						issued_status
					WHERE
						issued_date >= CURRENT_DATE - INTERVAL 2 MONTH);
                        
-- Task 17: Find Employees with the Most Book Issues Processed
-- Write a query to find the top 3 employees who have processed the most book issues. Display the employee name, number of books processed, and their branch.

SELECT 
    e.emp_name, b.*, COUNT(ist.issued_id) AS no_book_issued
FROM
    issued_status ist
        JOIN
    employees e ON ist.issued_emp_id = e.emp_id
        JOIN
    branch b ON e.branch_id = e.branch_id
GROUP BY e.emp_name , b.branch_id , b.branch_address , b.manager_id , b.contact_no;

/*
Task 19: Stored Procedure Objective: Create a stored procedure to manage the status of books in a library system. 
Description: Write a stored procedure that updates the status of a book in the library based on its issuance. 
The procedure should function as follows: The stored procedure should take the book_id as an input parameter. 
The procedure should first check if the book is available (status = 'yes'). 
If the book is available, it should be issued, and the status in the books table should be updated to 'no'. 
If the book is not available (status = 'no'), the procedure should return an error message indicating that the book is currently not available.
*/

DELIMITER $$

CREATE PROCEDURE update_issued_status(in p_issued_id varchar(10), in p_issued_member_id varchar(10),in p_issued_book_isbn varchar(20), in p_issued_emp_id varchar(10))
Begin
	declare v_status varchar(10);
    
SELECT 
    status
INTO v_status FROM
    books
WHERE
    isbn = p_issued_book_isbn;
    
    IF v_status ='yes' THEN
		insert into issued_status(issued_id, issued_member_id, issued_date, issued_book_isbn,issued_emp_id)
        values(p_issued_id, p_issued_member_id, Current_date, p_issued_book_isbn, p_issued_emp_id);
        
		UPDATE books 
		SET 
			status = 'no'
		WHERE
			isbn = p_issued_book_isbn;
	ELSE
			select 'Booked is unavailable sorry try for some other day.' as Notice_Alert;
	END IF;

End$$

DELIMITER ;

call sql_project_02.update_issued_status('IS161', 'C104', '978-0-14-118776-1', 'E106');

 