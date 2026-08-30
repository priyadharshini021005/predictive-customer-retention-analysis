-- Predictive Customer Retention Analysis using SQL
-- Phase 3: Database creation
-- This script creates the project database namespace only.

DROP DATABASE IF EXISTS predictive_customer_retention;
CREATE DATABASE predictive_customer_retention
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE predictive_customer_retention;

SELECT DATABASE() AS selected_database;
