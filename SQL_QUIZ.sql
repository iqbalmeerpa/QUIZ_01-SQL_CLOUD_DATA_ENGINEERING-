-- Q1. List top 5 customers by total order amount.
-- Retrieve the top 5 customers who have spent the most across all sales orders. Show CustomerID, CustomerName, and TotalSpent.

select TOP 5
	cust.first_name + ' ' + cust.last_name as full_name,
	SUM(ordIt.list_price) as order_amount
from sales.customers as cust
inner join sales.orders as ord
on ord.customer_id = cust.customer_id
inner join sales.order_items as ordIt
on ordIt.order_id = ord.order_id
group by cust.first_name,cust.last_name
order by order_amount desc


-- Q2. Find the number of products supplied by each supplier.
-- Display SupplierID, SupplierName, and ProductCount. Only include suppliers that have more than 10 products.

SELECT 
	sup.Name,
	COUNT(pod.ProductID) as ProductCount
FROM 
	dbo.Supplier as sup
INNER JOIN dbo.PurchaseOrder as po
ON po.SupplierID = sup.SupplierID
INNER JOIN dbo.PurchaseOrderDetail as pod
ON pod.OrderID = po.OrderID
GROUP BY sup.Name
HAVING COUNT(pod.ProductID)>10



-- Q3. Identify products that have been ordered but never returned.
-- Show ProductID, ProductName, and total order quantity.

SELECT 
	pr.Name,
	pr.ProductID
FROM dbo.Product as pr
WHERE pr.ProductID IN ( SELECT pod.ProductID
						FROM dbo.PurchaseOrderDetail as pod)
AND pr.ProductID NOT IN ( SELECT rod.ProductID
						FROM dbo.ReturnDetail as rod)

-- Q4. For each category, find the most expensive product.
-- Display CategoryID, CategoryName, ProductName, and Price. Use a subquery to get the max price per category.


SELECT
    c.CategoryID,
    c.Name as CategoryName,
    p.Name AS ProductName,
    p.Price
FROM dbo.Product p
INNER JOIN dbo.Category c
    ON c.CategoryID = p.CategoryID
WHERE p.Price =
(
    SELECT MAX(p2.Price)
    FROM dbo.Product p2
    WHERE p2.CategoryID = p.CategoryID
);


-- Q5. List all sales orders with customer name, product name, category, and supplier.
-- For each sales order, display:
-- OrderID, CustomerName, ProductName, CategoryName, SupplierName, and Quantity.

select 
	so.OrderID,
	cust.Name as CustomerName,
	pr.Name as ProductName,
	cat.Name as CategoryName,
	sup.Name as SupplierName,
    sod.Quantity
from dbo.SalesOrder as so
inner join dbo.Customer as cust
on cust.CustomerID = so.CustomerID
inner join dbo.SalesOrderDetail as sod
on sod.OrderID = so.OrderID
inner join dbo.Product as pr
on pr.ProductID = sod.ProductID
inner join dbo.Category as cat
on cat.CategoryID = pr.CategoryID
inner join PurchaseOrderDetail as pod
on pod.ProductID = pr.ProductID
inner join PurchaseOrder as po
on po.OrderID = pod.OrderID
inner join Supplier as sup
on sup.SupplierID = po.SupplierID


-- Q6. Find all shipments with details of warehouse, manager, and products shipped.
-- Display:
-- ShipmentID, WarehouseName, ManagerName, ProductName, QuantityShipped, and TrackingNumber.

SELECT
    s.ShipmentID,
    w.Capacity AS WarehouseName,
    e.Name AS ManagerName,
    p.Name AS ProductName,
    sd.Quantity AS QuantityShipped,
    s.TrackingNumber
FROM dbo.Shipment s
INNER JOIN dbo.Warehouse w
    ON w.WarehouseID = s.WarehouseID
INNER JOIN dbo.Employee e
    ON e.EmployeeID = w.ManagerID
INNER JOIN dbo.ShipmentDetail sd
    ON sd.ShipmentID = s.ShipmentID
INNER JOIN dbo.Product p
    ON p.ProductID = sd.ProductID
ORDER BY s.ShipmentID;

-- Q7. Find the top 3 highest-value orders per customer using RANK(). Display CustomerID, CustomerName, OrderID, and TotalAmount.

WITH CustomerOrderRank AS
(
    SELECT
        c.CustomerID,
        c.Name AS CustomerName,
        so.OrderID,
        so.TotalAmount,
        RANK() OVER
        (
            PARTITION BY c.CustomerID
            ORDER BY so.TotalAmount DESC
        ) AS OrderRank
    FROM dbo.Customer c
    INNER JOIN dbo.SalesOrder so
        ON so.CustomerID = c.CustomerID
)
SELECT
    CustomerID,
    CustomerName,
    OrderID,
    TotalAmount
FROM CustomerOrderRank
WHERE OrderRank <= 3
ORDER BY CustomerID, TotalAmount DESC;

-- Q8. For each product, show its sales history with the previous and next sales quantities (based on order date). Display ProductID, ProductName, OrderID, OrderDate, Quantity, PrevQuantity, and NextQuantity.

SELECT
    p.ProductID,
    p.Name AS ProductName,
    so.OrderID,
    so.OrderDate,
    sod.Quantity,

    LAG(sod.Quantity) OVER
    (
        PARTITION BY p.ProductID
        ORDER BY so.OrderDate
    ) AS PrevQuantity,

    LEAD(sod.Quantity) OVER
    (
        PARTITION BY p.ProductID
        ORDER BY so.OrderDate
    ) AS NextQuantity

FROM dbo.Product p
INNER JOIN dbo.SalesOrderDetail sod
    ON sod.ProductID = p.ProductID
INNER JOIN dbo.SalesOrder so
    ON so.OrderID = sod.OrderID
ORDER BY
    p.ProductID,
    so.OrderDate;

--Q9. Create a view named vw_CustomerOrderSummary that shows for each customer:
 -- CustomerID, CustomerName, TotalOrders, TotalAmountSpent, and LastOrderDate.

CREATE VIEW vw_CustomerOrderSummary
AS
SELECT
    c.CustomerID,
    c.Name AS CustomerName,
    COUNT(so.OrderID) AS TotalOrders,
    SUM(so.TotalAmount) AS TotalAmountSpent,
    MAX(so.OrderDate) AS LastOrderDate
FROM dbo.Customer c
LEFT JOIN dbo.SalesOrder so
    ON so.CustomerID = c.CustomerID
GROUP BY
    c.CustomerID,
    c.Name;
GO

SELECT *
FROM vw_CustomerOrderSummary;

-- Q10. Write a stored procedure sp_GetSupplierSales that takes a SupplierID as input and returns the total sales amount for all products supplied by that supplier.


CREATE PROCEDURE sp_GetSupplierSales
    @SupplierID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SupplierID,
        s.Name AS SupplierName,
        ISNULL(SUM(sod.TotalAmount),0) AS TotalSalesAmount
    FROM dbo.Supplier s
    INNER JOIN
    (
        SELECT DISTINCT
            po.SupplierID,
            pod.ProductID
        FROM dbo.PurchaseOrder po
        INNER JOIN dbo.PurchaseOrderDetail pod
            ON pod.OrderID = po.OrderID
    ) sp
        ON sp.SupplierID = s.SupplierID
    INNER JOIN dbo.SalesOrderDetail sod
        ON sod.ProductID = sp.ProductID
    WHERE (@SupplierID IS NULL OR s.SupplierID = @SupplierID)
    GROUP BY
        s.SupplierID,
        s.Name;
END;
EXECUTE sp_GetSupplierSales;