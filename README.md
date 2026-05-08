# Railway-Reservation-Management-System
The proposed system is a relational database application focused entirely on the backend layer. It models the full lifecycle of a railway ticket — from train search to booking, payment, and optional cancellation — using Oracle SQL and PL/SQL. 
The project uses Oracle Database as the primary RDBMS, executed through Oracle Live SQL or Oracle SQL
Developer. Oracle's PL/SQL procedural extension to SQL provides the ability to write stored procedures,
functions, triggers, cursors, and exception handlers — all of which are implemented in this project.
Oracle is a highly reliable, ACID-compliant enterprise RDBMS that supports complex queries, multi-user
concurrency control, and powerful procedural programming through PL/SQL. It is industry-standard for
large-scale data-driven applications, including railway and banking systems.

## User Roles

| Role      | Responsibilities |
|------------|------------------|
| **Admin** | Manages trains, stations, routes, and schedules. Can insert, update, and delete records across all tables. |
| **Passenger** | Searches for trains, makes bookings, views ticket details, initiates cancellations, and makes payments. |

# Database Tables

## 1. TRAIN🚅

| Attribute | Type | Description |
|-----------|------|-------------|
| Train_ID | NUMBER (PK) | Unique identifier for each train |
| Train_Name | VARCHAR2(100) | Name of the train |
| Train_Type | VARCHAR2(50) | Type: Express, Superfast, Passenger |
| Total_Seats | NUMBER | Total seating capacity of the train |
| Source_Station_ID | NUMBER (FK) | References Station table |
| Destination_Station_ID | NUMBER (FK) | References Station table |
| Departure_Time | TIMESTAMP | Scheduled departure time |
| Arrival_Time | TIMESTAMP | Scheduled arrival time |

---

## 2. STATION🚉

| Attribute | Type | Description |
|-----------|------|-------------|
| Station_ID | NUMBER (PK) | Unique station identifier |
| Station_Name | VARCHAR2(100) | Full name of the station |
| Station_Code | VARCHAR2(10) | Short code (e.g., NDLS, BCT) |
| City | VARCHAR2(50) | City where station is located |
| State | VARCHAR2(50) | State where station is located |

---

## 3. ROUTE

| Attribute | Type | Description |
|-----------|------|-------------|
| Route_ID | NUMBER (PK) | Unique route identifier |
| Train_ID | NUMBER (FK) | References Train table |
| Station_ID | NUMBER (FK) | References Station table |
| Stop_No | NUMBER | Sequence of stop on the route |
| Arrival_Time | TIMESTAMP | Arrival time at this stop |
| Departure_Time | TIMESTAMP | Departure time from this stop |
| Distance_From_Source | NUMBER | Km from source station |

---

## 4. PASSENGER🙍🏻‍♂️

| Attribute | Type | Description |
|-----------|------|-------------|
| Passenger_ID | NUMBER (PK) | Unique passenger identifier |
| Name | VARCHAR2(100) | Full name of passenger |
| Age | NUMBER | Age of the passenger |
| Gender | CHAR(1) | M / F / O |
| Phone | VARCHAR2(15) | Contact number |
| Email | VARCHAR2(100) | Email address |

---

## 5. BOOKING

| Attribute | Type | Description |
|-----------|------|-------------|
| Booking_ID | NUMBER (PK) | Unique booking identifier |
| Passenger_ID | NUMBER (FK) | References Passenger table |
| Train_ID | NUMBER (FK) | References Train table |
| Booking_Date | DATE | Date of booking |
| Journey_Date | DATE | Date of journey |
| Seat_Number | VARCHAR2(10) | Allocated seat number |
| Class | VARCHAR2(20) | Sleeper, AC, General, etc. |
| Booking_Status | VARCHAR2(20) | Confirmed, Waiting, Cancelled |

---

## 6. TICKET🎫

| Attribute | Type | Description |
|-----------|------|-------------|
| Ticket_No | NUMBER (PK) | Unique ticket number (PNR) |
| Booking_ID | NUMBER (FK) | References Booking table |
| Coach_No | VARCHAR2(10) | Coach identifier (e.g., S1, B2) |
| Seat_No | NUMBER | Seat number within coach |
| Berth_Type | VARCHAR2(5) | LB / MB / UB / SL / WL |
| Fare | NUMBER(10,2) | Final fare charged |

---

## 7. PAYMENT💸

| Attribute | Type | Description |
|-----------|------|-------------|
| Payment_ID | NUMBER (PK) | Unique payment identifier |
| Booking_ID | NUMBER (FK) | References Booking table |
| Amount | NUMBER(10,2) | Total amount paid |
| Payment_Mode | VARCHAR2(30) | UPI / Card / Net Banking / Cash |
| Payment_DateTime | TIMESTAMP | Date and time of payment |
| Payment_Status | VARCHAR2(20) | Success / Failed / Refunded |
| Transaction_Ref_No | VARCHAR2(50) | External transaction reference |
