# SupplyPulse – E-Grocery Inventory Intelligence

## Project Overview

SupplyPulse is an end-to-end inventory analytics project designed for an e-grocery business.

The project helps management identify stockout risk, oversold inventory, reorder requirements, expiry risk, supplier performance, warehouse performance, inventory value, and forecast accuracy.

The complete solution was built using Python, PostgreSQL, and Power BI.

---

## Business Problem

An e-grocery company manages many SKUs across multiple warehouses and suppliers.

Management needs to know:

- Which products are below safety stock?
- Which SKUs are oversold?
- Which products require reorder?
- Which inventory may expire soon?
- Which warehouse has higher inventory risk?
- Which suppliers have poor delivery performance?
- Where is most inventory capital invested?
- How accurate is demand forecasting?
- Which SKUs require immediate action?

---

## Project Objective

The objective of this project is to build an inventory intelligence system that converts raw inventory data into actionable business insights.

The solution helps management make better decisions related to:

- Inventory replenishment
- Stockout prevention
- Expiry reduction
- Supplier monitoring
- Warehouse performance
- Inventory capital management
- Demand forecasting

---

## Tools Used

- Python
- Pandas
- Jupyter Notebook
- PostgreSQL
- pgAdmin
- Power BI Desktop
- DAX
- Power Query

---

## Project Workflow

Raw E-Grocery Inventory Data  
↓  
Python Data Cleaning & EDA  
↓  
Business Feature Engineering  
↓  
PostgreSQL Business Analysis  
↓  
Star Schema Data Model  
↓  
Power BI Dashboard  
↓  
Management Insights & Actions

---

## Python Analysis

Python was used for:

- Data quality checks
- Missing value analysis
- Duplicate checks
- Data type validation
- Exploratory Data Analysis
- Inventory feature engineering

Important business features created include:

- Available to Promise (ATP)
- Oversold Flag
- Below Safety Stock Flag
- Reorder Flag
- Sellable ATP
- Sellable Coverage Days
- Expired Flag
- 30-Day Expiry Flag
- Dead Stock Flag

---

## SQL Analysis

20 business-focused PostgreSQL queries were created to analyze:

1. Overall Inventory Health
2. Stockout Risk
3. Oversold Inventory
4. Reorder Priority
5. Expiry Risk
6. Warehouse Performance
7. Supplier Performance
8. Inventory Capital
9. Forecast Performance
10. Critical SKU Action List

---

## Power BI Data Model

A Star Schema was created with:

### Fact Table

- Fact_Inventory

### Dimension Tables

- Dim_Product
- Dim_Supplier
- Dim_Warehouse
- Dim_Date

---

## Power BI Dashboard Pages

### 1. Executive Inventory Overview

Provides a management-level view of overall inventory performance.

### 2. Inventory Health & Risk

Focuses on stock risk, safety stock, oversold inventory, reorder requirements, and expiry risk.

### 3. Supplier & Warehouse Performance

Analyzes supplier reliability and warehouse-level inventory performance.

### 4. Forecasting & Action Center

Analyzes forecast accuracy and highlights SKUs requiring management attention.

---

## Key KPIs

- Total SKUs
- Total Inventory Value
- Below Safety Stock %
- Oversold SKUs
- Reorder Review SKUs
- Inventory Expiring Within 30 Days
- Sellable Coverage Days
- Supplier On-Time %
- Forecast Accuracy %

---

## Business Value

The dashboard helps management:

- Reduce stockout risk
- Identify urgent replenishment requirements
- Reduce inventory expiry losses
- Monitor supplier performance
- Improve warehouse decisions
- Optimize inventory investment
- Improve demand planning
- Prioritize critical SKUs

---

## Dashboard Preview

### Executive Inventory Overview

<img width="1201" height="672" alt="Executive" src="https://github.com/user-attachments/assets/5aa6a961-6a5e-41ea-89b5-b808525c5c17" />


### Inventory Health & Risk

<img width="1197" height="672" alt="Inventory" src="https://github.com/user-attachments/assets/d9f90ef5-5faa-4173-a2ac-d87b49494834" />


### Supplier & Warehouse Performance

<img width="1197" height="667" alt="Warehouse" src="https://github.com/user-attachments/assets/a1e1a184-ed18-45d2-a713-7eb4875a0a6a" />


### Forecasting & Action Center

<img width="1197" height="676" alt="Forecasting" src="https://github.com/user-attachments/assets/64cc2d42-7777-444d-8534-6a3dacb4c9ea" />


### Power BI Data Model

<img width="1680" height="678" alt="Relationship" src="https://github.com/user-attachments/assets/7ab189f9-a8d9-4737-8b50-9d5efb6fd1e3" />


---

## Repository Structure

```text
SupplyPulse-EGrocery-Inventory-Intelligence
│
├── data
│   ├── raw
│   └── cleaned
├── notebooks
├── sql
├── powerbi
├── screenshots
└── README.md
