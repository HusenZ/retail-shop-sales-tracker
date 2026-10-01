# Retail Shop Sales Tracker

## 1. Product Overview

A simple mobile-first sales tracking application for small retail shops, initially focused on mobile phone shops.

The app helps shop owners:

- Record sales quickly
- Create their own sale types and categories
- Track products and stock
- Track customers and pending payments
- See sales and profit
- Understand how their shop is performing
- Work even when internet connectivity is poor

The product should be **simple enough for a small shop owner to understand without training**.

---

# 2. Problem

Many small shop owners track business activity using:

- Notebooks
- WhatsApp messages
- Excel
- Basic billing applications

Existing retail software can be expensive or unnecessarily complicated for a small shop.

The app should solve a smaller, clearer problem:

> "I want to know what I sold, how much I made, what I have in stock, and how my shop is performing."

---

# 3. Target User

Primary user:

**Small mobile phone shop owner in India.**

Typical shop:

- 1 shop
- 1–3 employees
- Android phone
- Small number of daily transactions
- Sells phones and accessories
- May sell phones through different methods
- May accept cash, UPI, card, or credit
- May exchange old phones

The application should eventually support other retail businesses, but the MVP should focus on mobile shops.

---

# 4. Core Product Principle

### Keep everything simple.

A shop owner should be able to record a normal sale in **less than 30 seconds**.

Avoid unnecessary fields.

Do not force the user to configure the entire shop before making their first sale.

The app should guide the user gradually.

---

# 5. MVP Features

## 5.1 Authentication

The user can:

- Create an account
- Log in
- Log out

For the initial version, use simple authentication.

The application must associate all shop data with the correct shop/user.

---

# 6. Shop Setup

After registration, the user can create their shop.

Fields:

- Shop name
- Owner name
- Phone number
- Address — optional

The user can skip optional information.

---

# 7. Dashboard

The dashboard is the main screen.

It should show:

### Today's information

- Total sales
- Number of sales
- Profit

### Quick overview

- This week's sales
- This month's sales
- Pending customer payments

### Quick action

A prominent:

**+ Add Sale**

button.

Example:

```text
Good Morning 👋

Today's Sales
₹24,850

Profit
₹4,280

12 Transactions

-------------------

This Month
Sales       ₹4,82,500
Profit       ₹72,300

-------------------

[ + Add Sale ]
```

Keep the dashboard simple.

Do not overload it with charts in the first version.

---

# 8. Custom Sale Types

This is a core feature.

Every shop can define its own sale types.

Examples:

- New Phone Sale
- Old Phone Exchange
- Direct Retailer
- Wholesale
- Repair
- Accessories
- Corporate Sale

The user can:

- Create sale type
- Rename sale type
- Disable sale type
- Select a default sale type

Example:

```text
Sale Types

✓ New Phone
✓ Exchange
✓ Retailer
✓ Wholesale
✓ Repair

+ Add Sale Type
```

Do not hard-code these as permanent system values.

Provide sensible defaults during onboarding, but allow the shop owner to change them.

---

# 9. Custom Product Categories

The user can create categories.

Example:

- Mobile Phones
- Accessories
- Chargers
- Earphones
- Smart Watches
- Speakers
- Used Phones
- Repairs

The user can:

- Create category
- Rename category
- Disable category

Categories should belong to the shop.

---

# 10. Products

The user can create products.

Minimum fields:

- Product name
- Category
- Purchase price
- Selling price
- Stock quantity

Optional fields:

- Brand
- Model
- SKU
- IMEI

Example:

```text
Samsung A16

Category:
Mobile Phones

Purchase Price:
₹14,200

Selling Price:
₹15,999

Stock:
4
```

Do not build a complicated inventory system in MVP.

---

# 11. Add Sale

This is the most important workflow.

The user should be able to create a sale quickly.

Required:

- Sale type
- Product
- Quantity
- Selling price
- Payment method

Optional:

- Customer
- Discount
- Notes

Payment methods:

- Cash
- UPI
- Card
- Credit
- Other

The system calculates:

```text
Revenue = Selling Price × Quantity

Cost = Purchase Price × Quantity

Profit = Revenue - Cost
```

If a discount exists, calculate the final revenue after discount.

---

# 12. Sale History

The user can view previous transactions.

Each transaction should show:

- Date
- Product
- Sale type
- Amount
- Payment method
- Profit

Example:

```text
Today

Samsung A16
New Phone
₹15,999
UPI

iPhone 13
Exchange
₹32,000
Cash

Charger
Accessories
₹499
Cash
```

Allow filtering by:

- Date
- Sale type
- Category
- Payment method

---

# 13. Customers

Customers are optional.

A sale can be recorded without creating a customer.

Customer fields:

- Name
- Phone number
- Notes

Customer profile shows:

- Total purchases
- Number of transactions
- Pending amount

Example:

```text
Rahul

Purchases
₹84,500

Transactions
6

Pending
₹5,000
```

---

# 14. Credit / Pending Payments

A shop owner can mark a sale as credit.

Example:

```text
Total: ₹20,000

Paid: ₹15,000

Pending: ₹5,000
```

The app should track:

- Customer
- Total amount
- Paid amount
- Remaining amount
- Date

The user can record a payment later.

Do not build complex accounting.

---

# 15. Basic Inventory

Inventory should automatically change when products are sold.

Example:

```text
Samsung A16
Before sale: 5

Sold: 1

After sale: 4
```

Show:

- Current stock
- Low stock
- Out of stock

Allow the user to manually adjust stock.

---

# 16. Reports

The user should be able to understand their business without complicated accounting terminology.

Reports:

### Sales

- Today
- This week
- This month
- Custom date range

### Profit

- Total revenue
- Total cost
- Total profit

### Sale Types

Example:

```text
New Phone       ₹5,20,000
Exchange        ₹1,80,000
Retailer        ₹1,10,000
Wholesale          ₹32,000
```

### Categories

Example:

```text
Mobile Phones   ₹7,20,000
Accessories       ₹82,000
Repairs           ₹40,000
```

### Payment methods

```text
UPI       ₹3,20,000
Cash      ₹2,10,000
Card      ₹1,20,000
Credit      ₹50,000
```

Charts can be added only where they make the information easier to understand.

---

# 17. Phone Exchange

This is important for mobile shops but should remain simple.

When sale type is "Exchange", allow:

### New phone

- Product
- Selling price

### Old phone

- Model/name
- IMEI — optional
- Exchange value

Example:

```text
New Phone
iPhone 15
₹55,000

Old Phone
iPhone 12
₹18,000 exchange value

Customer Pays
₹37,000
```

The exchange workflow should still create a normal sale record.

Do not build a complicated used-phone valuation system in MVP.

---

# 18. Expenses

Allow shop owners to record simple business expenses.

Examples:

- Rent
- Electricity
- Salary
- Transport
- Other

Fields:

- Expense name
- Amount
- Date
- Note

Reports can show:

```text
Revenue
₹5,00,000

Gross Profit
₹80,000

Expenses
₹25,000

Net Profit
₹55,000
```

Keep expenses simple.

---

# 19. Offline Support

The app should remain usable when the internet connection is temporarily unavailable.

At minimum:

- User can view previously loaded data
- User can record a sale
- Sale is stored locally
- Sale synchronizes when internet returns

Do not build a complicated distributed synchronization system for MVP.

Use a simple local database and sync mechanism.

---

# 20. Data Model

Keep the initial database simple.

Core entities:

```text
User
Shop
Category
SaleType
Product
Customer
Sale
SaleItem
Payment
Expense
```

Basic relationships:

```text
Shop
 ├── Categories
 ├── Sale Types
 ├── Products
 ├── Customers
 ├── Sales
 └── Expenses

Sale
 ├── Sale Items
 └── Payments
```

Every shop-owned record must be associated with the correct shop.

---

# 21. Technology Stack

## Mobile

- Flutter
- Dart
- BLoC
- Clean Architecture
- Dio
- GoRouter
- Drift / SQLite

## Backend

- Python
- FastAPI
- SQLAlchemy
- Pydantic
- Alembic

## Database

- PostgreSQL

## Authentication

- Simple authentication solution
- Supabase Auth can be used initially if it reduces development complexity

## Storage

- Supabase Storage if file storage becomes necessary

## Deployment

Start with a simple low-cost deployment.

Do not introduce:

- Kubernetes
- Microservices
- Kafka
- Redis
- Complex event-driven architecture

unless there is an actual requirement.

---

# 22. Subscription Plans

The application should support subscriptions from the beginning at the data-model level, but payment integration does not need to block the MVP.

Initial plans:

### Free

₹0/year

- Basic sales tracking
- Custom categories
- Custom sale types
- Basic dashboard
- Limited products
- Basic sales history

### Starter

₹499/year

- Unlimited products
- Inventory
- Customers
- Reports
- Profit tracking
- Cloud backup

### Business

₹999/year

- Everything in Starter
- Phone exchange
- Credit tracking
- Expenses
- Advanced reports
- Multiple devices
- Invoice/receipt features

### Pro — Later

₹1,499/year

Potential features:

- Staff accounts
- Staff permissions
- Advanced analytics
- AI business assistant

Do not implement all Pro features in MVP.

---

# 23. Payments

The application will eventually use Razorpay for subscriptions.

Expected flow:

```text
Flutter
   ↓
FastAPI
   ↓
Razorpay
   ↓
Webhook
   ↓
FastAPI
   ↓
Database
```

The backend should determine the user's subscription status.

Never trust only the mobile application to determine whether a user has an active subscription.

---

# 24. AI Features — Future

AI is not part of the core MVP.

Later, the owner can ask questions such as:

> How much did I earn from exchanges this month?

> Which category made the most profit?

> How much money is pending from customers?

> What were my sales last week?

The backend should first retrieve accurate structured data.

The LLM should interpret and explain that data.

The LLM should **not be responsible for calculating financial numbers when the database can provide them directly.**

---

# 25. UI/UX Principles

The target user may not be technically comfortable.

Therefore:

- Large buttons
- Simple language
- Minimal forms
- Clear numbers
- Few screens
- Fast actions
- Avoid technical terminology
- Avoid unnecessary configuration

The most important action should always be easy to find:

**Add Sale**

Do not make the user navigate through multiple screens just to record a simple sale.

---

# 26. Main Navigation

Use a simple bottom navigation:

```text
Dashboard
Sales
Products
Reports
Settings
```

Customers can be accessed from Sales or a relevant section rather than adding another bottom-navigation item.

---

# 27. MVP Success Criteria

The MVP is successful when a shop owner can:

1. Create their shop
2. Create categories
3. Create sale types
4. Add products
5. Record a sale in under 30 seconds
6. See today's sales
7. See profit
8. View previous sales
9. Track basic stock
10. Track customer credit
11. View monthly reports
12. Continue recording sales during temporary internet problems

If these work reliably, the MVP is ready for real-world testing.

---

# 28. Development Priority

Build in this order:

### Phase 1 — Foundation

- Project setup
- Authentication
- Shop setup
- Database
- API structure

### Phase 2 — Core Sales

- Categories
- Sale types
- Products
- Add sale
- Sale history

### Phase 3 — Business Tracking

- Dashboard
- Customers
- Credit
- Inventory
- Expenses

### Phase 4 — Reports

- Sales reports
- Profit reports
- Category reports
- Sale-type reports
- Payment reports

### Phase 5 — Offline

- Local database
- Offline sale creation
- Basic synchronization

### Phase 6 — Subscription

- Free plan
- Paid plans
- Subscription status
- Razorpay integration

### Phase 7 — Future Features

- Invoices
- WhatsApp sharing
- Staff accounts
- Advanced exchange workflow
- AI assistant

---

# 29. Important Development Rules

### Rule 1 — Don't over-engineer

Solve the current problem with the simplest reliable implementation.

### Rule 2 — Don't build future features early

If a feature isn't required for the MVP, don't implement it just because it might be useful later.

### Rule 3 — Business logic belongs in the backend

The Flutter application should not be the source of truth for:

- Profit
- Subscription status
- Permissions
- Important financial calculations

### Rule 4 — Keep the database understandable

Prefer simple tables and relationships over complicated abstractions.

### Rule 5 — Build feature by feature

Each feature should work end-to-end before moving to the next one.

Example:

```text
Add Product
    ↓
Save to database
    ↓
Display product
    ↓
Edit product
    ↓
Delete/disable product
```

Don't create all screens first and connect them later.

### Rule 6 — Test real workflows

Think like a shop owner.

Example:

```text
Create shop
    ↓
Create "Mobile Phones"
    ↓
Create "New Phone Sale"
    ↓
Add Samsung A16
    ↓
Record sale
    ↓
Stock decreases
    ↓
Sales increase
    ↓
Profit updates
    ↓
Dashboard updates
```

This complete workflow is more important than having many screens.

---

# 30. Product Philosophy

The application is not trying to replace a large ERP system.

It solves a focused problem:

> **Help small shop owners understand and manage their daily sales without complicated software.**

The product should feel:

**Simple → Fast → Affordable → Useful**

Build the smallest version that solves the problem, put it in the hands of real shop owners, learn what they actually need, and expand from there.
