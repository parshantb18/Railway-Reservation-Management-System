-- ============================================================
-- SECTION 0: SCHEMA CLEANUP
-- Drops all E-RAIL objects in one block before recreating them.
-- Safe to run on a fresh schema (errors are silently ignored).
-- ============================================================

BEGIN
  -- Drop dependent objects first, then tables (CASCADE handles FK order)
  FOR obj IN (
    SELECT object_type, object_name FROM user_objects
    WHERE object_name IN (
      'CANCEL_TRIGGER','BEFORE_BOOKING_TRIGGER','BOOKING_LOG_TRIGGER',
      'BOOK_TICKET','CANCEL_BOOKING',
      'CALC_FARE','GET_AVAILABLE_SEATS',
      'TRAIN_SCHEDULE',
      'PAYMENT','TICKET','BOOKING','BOOKING_LOG','ROUTE','TRAIN','PASSENGER','STATION',
      'BOOKING_LOG_SEQ'
    )
  ) LOOP
    BEGIN
      IF obj.object_type = 'TABLE' THEN
        EXECUTE IMMEDIATE 'DROP TABLE ' || obj.object_name || ' CASCADE CONSTRAINTS';
      ELSE
        EXECUTE IMMEDIATE 'DROP ' || obj.object_type || ' ' || obj.object_name;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/


-- ============================================================
-- SECTION 1: DDL - CREATE TABLES
-- Order matters: referenced tables must be created first.
-- Station → Train → Route → Passenger → Booking → Ticket → Payment
-- ============================================================

-- -------------------------------------------------------
-- 1.1 STATION Table
-- Stores all railway stations with their codes and location.
-- Created first as it is referenced by Train, Route, and Booking.
-- -------------------------------------------------------
CREATE TABLE Station (
    Station_ID      NUMBER          PRIMARY KEY,
    Station_Name    VARCHAR2(100)   NOT NULL,
    Station_Code    VARCHAR2(10)    UNIQUE NOT NULL,
    City            VARCHAR2(50),
    State           VARCHAR2(50)
);

-- -------------------------------------------------------
-- 1.2 TRAIN Table
-- Stores train master data including capacity and schedule.
-- Available_Seats tracks real-time remaining seats.
-- References Station twice: source and destination.
-- -------------------------------------------------------
CREATE TABLE Train (
    Train_ID                NUMBER          PRIMARY KEY,
    Train_Name              VARCHAR2(100)   NOT NULL,
    Train_Type              VARCHAR2(50),
    Total_Seats             NUMBER          NOT NULL,
    Available_Seats         NUMBER          NOT NULL,
    Source_Station_ID       NUMBER,
    Destination_Station_ID  NUMBER,
    Departure_Time          TIMESTAMP,
    Arrival_Time            TIMESTAMP,
    CONSTRAINT chk_avail_seats CHECK (Available_Seats >= 0),
    CONSTRAINT chk_total_seats CHECK (Total_Seats > 0),
    FOREIGN KEY (Source_Station_ID)      REFERENCES Station(Station_ID),
    FOREIGN KEY (Destination_Station_ID) REFERENCES Station(Station_ID)
);

-- -------------------------------------------------------
-- 1.3 ROUTE Table
-- Captures the intermediate stops of each train journey.
-- Each row is one stop on one train's route.
-- -------------------------------------------------------
CREATE TABLE Route (
    Route_ID                NUMBER          PRIMARY KEY,
    Train_ID                NUMBER,
    Station_ID              NUMBER,
    Stop_No                 NUMBER          NOT NULL,
    Arrival_Time            TIMESTAMP,
    Departure_Time          TIMESTAMP,
    Distance_From_Source    NUMBER,
    FOREIGN KEY (Train_ID)   REFERENCES Train(Train_ID),
    FOREIGN KEY (Station_ID) REFERENCES Station(Station_ID)
);

-- -------------------------------------------------------
-- 1.4 PASSENGER Table
-- Stores passenger personal information.
-- Email is UNIQUE to prevent duplicate registrations.
-- -------------------------------------------------------
CREATE TABLE Passenger (
    Passenger_ID    NUMBER          PRIMARY KEY,
    Name            VARCHAR2(100)   NOT NULL,
    Age             NUMBER          CHECK (Age > 0 AND Age <= 120),
    Gender          CHAR(1)         CHECK (Gender IN ('M', 'F', 'O')),
    Phone           VARCHAR2(15),
    Email           VARCHAR2(100)   UNIQUE
);

-- -------------------------------------------------------
-- 1.5 BOOKING Table
-- Central table linking passenger, train, and journey details.
-- Includes source/destination stations for segment-based booking.
-- -------------------------------------------------------
CREATE TABLE Booking (
    Booking_ID          NUMBER          PRIMARY KEY,
    Passenger_ID        NUMBER,
    Train_ID            NUMBER,
    Source_Station_ID   NUMBER,
    Dest_Station_ID     NUMBER,
    Journey_Date        DATE            NOT NULL,
    Booking_Date        DATE            DEFAULT SYSDATE,
    Booking_Status      VARCHAR2(20)    CHECK (Booking_Status IN ('Confirmed', 'Waitlisted', 'Cancelled')),
    No_Of_Seats         NUMBER          DEFAULT 1,
    Class_Type          VARCHAR2(10)    CHECK (Class_Type IN ('SL', '3A', '2A', '1A', 'CC')),
    FOREIGN KEY (Passenger_ID)      REFERENCES Passenger(Passenger_ID),
    FOREIGN KEY (Train_ID)          REFERENCES Train(Train_ID),
    FOREIGN KEY (Source_Station_ID) REFERENCES Station(Station_ID),
    FOREIGN KEY (Dest_Station_ID)   REFERENCES Station(Station_ID)
);

-- -------------------------------------------------------
-- 1.6 BOOKING_LOG Table
-- Audit table automatically populated by booking_log_trigger.
-- Records every booking insert with timestamp for traceability.
-- -------------------------------------------------------
CREATE TABLE Booking_Log (
    Log_ID          NUMBER          PRIMARY KEY,
    Booking_ID      NUMBER,
    Passenger_ID    NUMBER,
    Train_ID        NUMBER,
    Log_Time        TIMESTAMP       DEFAULT SYSTIMESTAMP,
    Action          VARCHAR2(50)
);

-- Create a sequence for Log_ID auto-increment
CREATE SEQUENCE booking_log_seq START WITH 1 INCREMENT BY 1;

-- -------------------------------------------------------
-- 1.7 TICKET Table
-- Stores the issued ticket (PNR) details per booking.
-- One booking generates exactly one ticket (1:1 relationship).
-- -------------------------------------------------------
CREATE TABLE Ticket (
    Ticket_No   NUMBER          PRIMARY KEY,
    Booking_ID  NUMBER          UNIQUE,
    Coach_No    VARCHAR2(10),
    Seat_No     NUMBER,
    Berth_Type  VARCHAR2(5)     CHECK (Berth_Type IN ('LB', 'MB', 'UB', 'SL', 'WL')),
    Fare        NUMBER(10, 2)   CHECK (Fare >= 0),
    FOREIGN KEY (Booking_ID) REFERENCES Booking(Booking_ID)
);

-- -------------------------------------------------------
-- 1.8 PAYMENT Table
-- Stores payment details linked to a booking.
-- One booking has exactly one payment record (1:1 relationship).
-- -------------------------------------------------------
CREATE TABLE Payment (
    Payment_ID          NUMBER          PRIMARY KEY,
    Booking_ID          NUMBER          UNIQUE,
    Amount              NUMBER(10, 2)   NOT NULL,
    Payment_Mode        VARCHAR2(30)    CHECK (Payment_Mode IN ('UPI', 'Card', 'Net Banking', 'Cash')),
    Payment_DateTime    TIMESTAMP       DEFAULT SYSTIMESTAMP,
    Payment_Status      VARCHAR2(20)    CHECK (Payment_Status IN ('Success', 'Failed', 'Refunded')),
    Transaction_Ref_No  VARCHAR2(50),
    FOREIGN KEY (Booking_ID) REFERENCES Booking(Booking_ID)
);


-- ============================================================
-- SECTION 2: DML - INSERT DATA
-- ============================================================

-- -------------------------------------------------------
-- 2.1 Station Data (7 major Indian railway stations)
-- -------------------------------------------------------
INSERT INTO Station VALUES (1, 'New Delhi',        'NDLS', 'New Delhi', 'Delhi');
INSERT INTO Station VALUES (2, 'Mumbai Central',   'BCT',  'Mumbai',    'Maharashtra');
INSERT INTO Station VALUES (3, 'Chennai Central',  'MAS',  'Chennai',   'Tamil Nadu');
INSERT INTO Station VALUES (4, 'Howrah Junction',  'HWH',  'Kolkata',   'West Bengal');
INSERT INTO Station VALUES (5, 'Amritsar Jn',      'ASR',  'Amritsar',  'Punjab');
INSERT INTO Station VALUES (6, 'Bangalore City',   'SBC',  'Bangalore', 'Karnataka');
INSERT INTO Station VALUES (7, 'Hyderabad Deccan', 'HYB',  'Hyderabad', 'Telangana');

-- -------------------------------------------------------
-- 2.2 Train Data (5 trains with real-time Available_Seats)
-- Available_Seats starts equal to Total_Seats before any bookings.
-- Triggers and procedures will decrement this as bookings are made.
-- -------------------------------------------------------
INSERT INTO Train VALUES (
    101, 'Rajdhani Express', 'Superfast', 500, 497, 1, 2,
    TO_TIMESTAMP('2026-05-10 16:00', 'YYYY-MM-DD HH24:MI'),
    TO_TIMESTAMP('2026-05-11 08:00', 'YYYY-MM-DD HH24:MI')
);
INSERT INTO Train VALUES (
    102, 'Punjab Mail', 'Express', 800, 798, 5, 2,
    TO_TIMESTAMP('2026-05-10 09:00', 'YYYY-MM-DD HH24:MI'),
    TO_TIMESTAMP('2026-05-11 05:30', 'YYYY-MM-DD HH24:MI')
);
INSERT INTO Train VALUES (
    103, 'Chennai Express', 'Superfast', 600, 598, 1, 3,
    TO_TIMESTAMP('2026-05-10 22:00', 'YYYY-MM-DD HH24:MI'),
    TO_TIMESTAMP('2026-05-11 18:30', 'YYYY-MM-DD HH24:MI')
);
INSERT INTO Train VALUES (
    104, 'Howrah Mail', 'Express', 750, 748, 1, 4,
    TO_TIMESTAMP('2026-05-10 23:55', 'YYYY-MM-DD HH24:MI'),
    TO_TIMESTAMP('2026-05-12 07:00', 'YYYY-MM-DD HH24:MI')
);
INSERT INTO Train VALUES (
    105, 'Bangalore Exp', 'Superfast', 550, 549, 1, 6,
    TO_TIMESTAMP('2026-05-10 20:30', 'YYYY-MM-DD HH24:MI'),
    TO_TIMESTAMP('2026-05-11 14:00', 'YYYY-MM-DD HH24:MI')
);

-- -------------------------------------------------------
-- 2.3 Route Data (intermediate stops for each train)
-- -------------------------------------------------------
INSERT INTO Route VALUES (1, 101, 1, 1, NULL,
    TO_TIMESTAMP('2026-05-10 16:00','YYYY-MM-DD HH24:MI'), 0);
INSERT INTO Route VALUES (2, 101, 2, 2,
    TO_TIMESTAMP('2026-05-11 08:00','YYYY-MM-DD HH24:MI'), NULL, 1384);

INSERT INTO Route VALUES (3, 102, 5, 1, NULL,
    TO_TIMESTAMP('2026-05-10 09:00','YYYY-MM-DD HH24:MI'), 0);
INSERT INTO Route VALUES (4, 102, 1, 2,
    TO_TIMESTAMP('2026-05-10 14:30','YYYY-MM-DD HH24:MI'),
    TO_TIMESTAMP('2026-05-10 15:00','YYYY-MM-DD HH24:MI'), 450);
INSERT INTO Route VALUES (5, 102, 2, 3,
    TO_TIMESTAMP('2026-05-11 05:30','YYYY-MM-DD HH24:MI'), NULL, 1926);

INSERT INTO Route VALUES (6, 103, 1, 1, NULL,
    TO_TIMESTAMP('2026-05-10 22:00','YYYY-MM-DD HH24:MI'), 0);
INSERT INTO Route VALUES (7, 103, 3, 2,
    TO_TIMESTAMP('2026-05-11 18:30','YYYY-MM-DD HH24:MI'), NULL, 2180);

INSERT INTO Route VALUES (8, 104, 1, 1, NULL,
    TO_TIMESTAMP('2026-05-10 23:55','YYYY-MM-DD HH24:MI'), 0);
INSERT INTO Route VALUES (9, 104, 4, 2,
    TO_TIMESTAMP('2026-05-12 07:00','YYYY-MM-DD HH24:MI'), NULL, 1472);

INSERT INTO Route VALUES (10, 105, 1, 1, NULL,
    TO_TIMESTAMP('2026-05-10 20:30','YYYY-MM-DD HH24:MI'), 0);
INSERT INTO Route VALUES (11, 105, 6, 2,
    TO_TIMESTAMP('2026-05-11 14:00','YYYY-MM-DD HH24:MI'), NULL, 2150);

-- -------------------------------------------------------
-- 2.4 Passenger Data (7 passengers)
-- -------------------------------------------------------
INSERT INTO Passenger VALUES (1, 'Amit Sharma',  35, 'M', '9876543210', 'amit.sharma@email.com');
INSERT INTO Passenger VALUES (2, 'Priya Singh',  28, 'F', '9012345678', 'priya.singh@email.com');
INSERT INTO Passenger VALUES (3, 'Ravi Patel',   42, 'M', '9123456789', 'ravi.patel@email.com');
INSERT INTO Passenger VALUES (4, 'Sunita Rao',   31, 'F', '9234567890', 'sunita.rao@email.com');
INSERT INTO Passenger VALUES (5, 'Arun Kumar',   25, 'M', '9345678901', 'arun.kumar@email.com');
INSERT INTO Passenger VALUES (6, 'Meena Joshi',  38, 'F', '9456789012', 'meena.joshi@email.com');
INSERT INTO Passenger VALUES (7, 'Vikram Das',   55, 'M', '9567890123', 'vikram.das@email.com');

-- -------------------------------------------------------
-- 2.5 Booking Data (8 bookings matching report exactly)
-- -------------------------------------------------------
INSERT INTO Booking VALUES (1, 1, 101, 1, 2, DATE '2026-05-10', DATE '2026-04-20', 'Confirmed',  1, '3A');
INSERT INTO Booking VALUES (2, 2, 101, 1, 2, DATE '2026-05-10', DATE '2026-04-21', 'Confirmed',  2, 'SL');
INSERT INTO Booking VALUES (3, 3, 102, 5, 2, DATE '2026-05-10', DATE '2026-04-22', 'Waitlisted', 1, '2A');
INSERT INTO Booking VALUES (4, 4, 103, 1, 3, DATE '2026-05-10', DATE '2026-04-18', 'Confirmed',  1, '1A');
INSERT INTO Booking VALUES (5, 5, 104, 1, 4, DATE '2026-05-10', DATE '2026-04-25', 'Confirmed',  2, 'SL');
INSERT INTO Booking VALUES (6, 6, 105, 1, 6, DATE '2026-05-10', DATE '2026-04-19', 'Confirmed',  1, 'CC');
INSERT INTO Booking VALUES (7, 7, 102, 5, 2, DATE '2026-05-11', DATE '2026-04-23', 'Cancelled',  1, '3A');
INSERT INTO Booking VALUES (8, 1, 103, 1, 3, DATE '2026-05-12', DATE '2026-04-20', 'Confirmed',  1, '2A');

-- -------------------------------------------------------
-- 2.6 Ticket Data (7 tickets; Booking 7 is cancelled, no ticket)
-- -------------------------------------------------------
INSERT INTO Ticket VALUES (5001, 1, 'B2', 42, 'LB', 1250.00);
INSERT INTO Ticket VALUES (5002, 2, 'S5', 15, 'SL',  850.00);
INSERT INTO Ticket VALUES (5003, 3, 'A1',  8, 'UB', 2100.00);
INSERT INTO Ticket VALUES (5004, 4, 'A1',  1, 'LB', 3500.00);
INSERT INTO Ticket VALUES (5005, 5, 'S8', 30, 'SL',  900.00);
INSERT INTO Ticket VALUES (5006, 6, 'C2', 22, 'WL', 1800.00);
INSERT INTO Ticket VALUES (5007, 8, 'B3', 11, 'MB', 2050.00);

-- -------------------------------------------------------
-- 2.7 Payment Data (7 payments; cancelled booking 7 has no payment)
-- -------------------------------------------------------
INSERT INTO Payment VALUES (101, 1, 1250.00, 'UPI',         SYSTIMESTAMP, 'Success',  'UPI20260420001');
INSERT INTO Payment VALUES (102, 2, 1700.00, 'Card',        SYSTIMESTAMP, 'Success',  'CARD20260421002');
INSERT INTO Payment VALUES (103, 3, 2100.00, 'Net Banking',  SYSTIMESTAMP, 'Success',  'NB20260422003');
INSERT INTO Payment VALUES (104, 4, 3500.00, 'Card',        SYSTIMESTAMP, 'Success',  'CARD20260418004');
INSERT INTO Payment VALUES (105, 5, 1800.00, 'UPI',         SYSTIMESTAMP, 'Success',  'UPI20260425005');
INSERT INTO Payment VALUES (106, 6, 1800.00, 'Cash',        SYSTIMESTAMP, 'Success',  'CASH20260419006');
INSERT INTO Payment VALUES (107, 8, 2050.00, 'UPI',         SYSTIMESTAMP, 'Success',  'UPI20260420007');

COMMIT;


-- ============================================================
-- SECTION 3: SELECT QUERIES
-- ============================================================

-- -------------------------------------------------------
-- Query 1: All confirmed bookings with passenger and train name
-- Demonstrates: Multi-table JOIN, WHERE filter, ORDER BY
-- -------------------------------------------------------
SELECT
    b.Booking_ID,
    p.Name           AS Passenger_Name,
    t.Train_Name,
    b.Journey_Date,
    b.Class_Type,
    b.No_Of_Seats,
    b.Booking_Status
FROM Booking b
JOIN Passenger p ON b.Passenger_ID = p.Passenger_ID
JOIN Train     t ON b.Train_ID     = t.Train_ID
WHERE b.Booking_Status = 'Confirmed'
ORDER BY b.Journey_Date;

-- -------------------------------------------------------
-- Query 2: Total revenue per train (only successful payments)
-- Demonstrates: JOIN across 3 tables, GROUP BY, aggregate SUM/COUNT
-- -------------------------------------------------------
SELECT
    t.Train_Name,
    COUNT(b.Booking_ID)  AS Total_Bookings,
    SUM(pay.Amount)      AS Total_Revenue
FROM Train   t
JOIN Booking b   ON t.Train_ID     = b.Train_ID
JOIN Payment pay ON b.Booking_ID   = pay.Booking_ID
WHERE pay.Payment_Status = 'Success'
GROUP BY t.Train_Name
ORDER BY Total_Revenue DESC;

-- -------------------------------------------------------
-- Query 3: Trains with more than 1 confirmed booking
-- Demonstrates: GROUP BY with HAVING clause
-- -------------------------------------------------------
SELECT
    t.Train_Name,
    COUNT(b.Booking_ID) AS Confirmed_Bookings
FROM Train   t
JOIN Booking b ON t.Train_ID = b.Train_ID
WHERE b.Booking_Status = 'Confirmed'
GROUP BY t.Train_Name
HAVING COUNT(b.Booking_ID) > 1;

-- -------------------------------------------------------
-- Query 4: Passengers with no bookings
-- Demonstrates: Subquery with NOT IN
-- -------------------------------------------------------
SELECT
    Passenger_ID,
    Name,
    Email
FROM Passenger
WHERE Passenger_ID NOT IN (
    SELECT DISTINCT Passenger_ID FROM Booking
);

-- -------------------------------------------------------
-- Query 5: View - Train Schedule with source/destination names
-- Demonstrates: CREATE VIEW, self-join on Station
-- -------------------------------------------------------
CREATE OR REPLACE VIEW Train_Schedule AS
SELECT
    t.Train_ID,
    t.Train_Name,
    t.Train_Type,
    s1.Station_Name   AS Source_Station,
    s2.Station_Name   AS Destination_Station,
    t.Departure_Time,
    t.Arrival_Time,
    t.Total_Seats,
    t.Available_Seats
FROM Train   t
JOIN Station s1 ON t.Source_Station_ID      = s1.Station_ID
JOIN Station s2 ON t.Destination_Station_ID = s2.Station_ID;

-- Query the view
SELECT * FROM Train_Schedule ORDER BY Train_ID;

-- -------------------------------------------------------
-- Query 6: Ticket details with berth type for confirmed bookings
-- Demonstrates: 4-table JOIN, specific column selection
-- -------------------------------------------------------
SELECT
    tk.Ticket_No,
    p.Name       AS Passenger,
    t.Train_Name,
    tk.Coach_No,
    tk.Seat_No,
    tk.Berth_Type,
    tk.Fare
FROM Ticket  tk
JOIN Booking  b  ON tk.Booking_ID  = b.Booking_ID
JOIN Passenger p ON b.Passenger_ID = p.Passenger_ID
JOIN Train     t ON b.Train_ID     = t.Train_ID
WHERE b.Booking_Status = 'Confirmed'
ORDER BY tk.Ticket_No;

-- -------------------------------------------------------
-- Query 7 (Analytical): Class-wise revenue breakdown
-- Demonstrates: GROUP BY on multiple columns, ROUND
-- -------------------------------------------------------
SELECT
    b.Class_Type,
    COUNT(b.Booking_ID)       AS Total_Bookings,
    SUM(pay.Amount)           AS Total_Revenue,
    ROUND(AVG(pay.Amount), 2) AS Avg_Fare_Per_Booking
FROM Booking b
JOIN Payment pay ON b.Booking_ID = pay.Booking_ID
WHERE pay.Payment_Status = 'Success'
GROUP BY b.Class_Type
ORDER BY Total_Revenue DESC;

-- -------------------------------------------------------
-- Query 8 (Analytical): Payment mode usage frequency
-- Demonstrates: GROUP BY, COUNT, ORDER BY on aggregate
-- -------------------------------------------------------
SELECT
    Payment_Mode,
    COUNT(*)          AS Transactions,
    SUM(Amount)       AS Total_Collected,
    ROUND(AVG(Amount), 2) AS Avg_Transaction_Value
FROM Payment
WHERE Payment_Status = 'Success'
GROUP BY Payment_Mode
ORDER BY Total_Collected DESC;

-- -------------------------------------------------------
-- Query 9 (Analytical): Passenger with highest total spending
-- Demonstrates: 3-table JOIN, GROUP BY, ORDER BY DESC
-- -------------------------------------------------------
SELECT
    p.Passenger_ID,
    p.Name              AS Passenger_Name,
    COUNT(b.Booking_ID) AS Total_Bookings,
    SUM(pay.Amount)     AS Total_Spent
FROM Passenger p
JOIN Booking  b   ON p.Passenger_ID = b.Passenger_ID
JOIN Payment  pay ON b.Booking_ID   = pay.Booking_ID
WHERE pay.Payment_Status = 'Success'
GROUP BY p.Passenger_ID, p.Name
ORDER BY Total_Spent DESC;

-- -------------------------------------------------------
-- Query 10 (Analytical): Berth-type wise seat distribution
-- Demonstrates: Counting by category within confirmed tickets
-- -------------------------------------------------------
SELECT
    tk.Berth_Type,
    COUNT(*)              AS Seats_Booked,
    SUM(tk.Fare)          AS Total_Fare,
    ROUND(AVG(tk.Fare),2) AS Avg_Fare
FROM Ticket  tk
JOIN Booking b ON tk.Booking_ID = b.Booking_ID
WHERE b.Booking_Status IN ('Confirmed', 'Waitlisted')
GROUP BY tk.Berth_Type
ORDER BY Seats_Booked DESC;

-- -------------------------------------------------------
-- Query 11 (Analytical): Most booked train using subquery
-- Demonstrates: Nested aggregate subquery
-- -------------------------------------------------------
SELECT
    Train_ID,
    COUNT(*) AS Total_Bookings
FROM Booking
GROUP BY Train_ID
HAVING COUNT(*) = (
    SELECT MAX(cnt) FROM (
        SELECT COUNT(*) AS cnt FROM Booking GROUP BY Train_ID
    )
);

-- -------------------------------------------------------
-- Query 12 (Analytical): Cancellation rate per train
-- Demonstrates: CASE WHEN inside aggregate, percentage calculation
-- -------------------------------------------------------
SELECT
    t.Train_Name,
    COUNT(b.Booking_ID)                                               AS Total_Bookings,
    SUM(CASE WHEN b.Booking_Status = 'Cancelled' THEN 1 ELSE 0 END)  AS Cancelled_Count,
    ROUND(
        SUM(CASE WHEN b.Booking_Status = 'Cancelled' THEN 1 ELSE 0 END)
        * 100 / COUNT(b.Booking_ID), 2
    )                                                                  AS Cancellation_Pct
FROM Train   t
JOIN Booking b ON t.Train_ID = b.Train_ID
GROUP BY t.Train_Name
ORDER BY Cancellation_Pct DESC;


-- ============================================================
-- SECTION 4: PL/SQL - STORED PROCEDURES
-- ============================================================

-- -------------------------------------------------------
-- Procedure 1: Book_Ticket (Full version from report)
-- Computes available seats by querying Total_Seats and existing
-- confirmed/waitlisted bookings. Sets status accordingly.
-- Auto-generates Booking_ID using MAX()+1.
-- Includes exception handling for missing train/station.
-- -------------------------------------------------------
CREATE OR REPLACE PROCEDURE Book_Ticket (
    p_passenger_id    IN Booking.Passenger_ID%TYPE,
    p_train_id        IN Booking.Train_ID%TYPE,
    p_src_station_id  IN Booking.Source_Station_ID%TYPE,
    p_dest_station_id IN Booking.Dest_Station_ID%TYPE,
    p_journey_date    IN Booking.Journey_Date%TYPE,
    p_class_type      IN Booking.Class_Type%TYPE,
    p_no_seats        IN Booking.No_Of_Seats%TYPE
) AS
    v_total_seats     NUMBER;
    v_booked_seats    NUMBER;
    v_avail_seats     NUMBER;
    v_new_booking_id  NUMBER;
    v_status          VARCHAR2(20);
BEGIN
    -- Fetch total capacity of the train
    SELECT Total_Seats INTO v_total_seats
    FROM Train
    WHERE Train_ID = p_train_id;

    -- Count already occupied seats on the same journey date
    SELECT NVL(SUM(No_Of_Seats), 0) INTO v_booked_seats
    FROM Booking
    WHERE Train_ID       = p_train_id
      AND Journey_Date   = p_journey_date
      AND Booking_Status IN ('Confirmed', 'Waitlisted');

    v_avail_seats := v_total_seats - v_booked_seats;

    -- Determine booking status based on seat availability
    IF p_no_seats <= v_avail_seats THEN
        v_status := 'Confirmed';
    ELSE
        v_status := 'Waitlisted';
    END IF;

    -- Auto-generate the next Booking_ID
    SELECT NVL(MAX(Booking_ID), 0) + 1 INTO v_new_booking_id FROM Booking;

    -- Insert the new booking record
    INSERT INTO Booking (
        Booking_ID, Passenger_ID, Train_ID,
        Source_Station_ID, Dest_Station_ID,
        Journey_Date, Booking_Date,
        Booking_Status, No_Of_Seats, Class_Type
    ) VALUES (
        v_new_booking_id, p_passenger_id, p_train_id,
        p_src_station_id, p_dest_station_id,
        p_journey_date, SYSDATE,
        v_status, p_no_seats, p_class_type
    );

    DBMS_OUTPUT.PUT_LINE(
        'Booking Successful! ID: ' || v_new_booking_id ||
        ' | Status: '  || v_status ||
        ' | Seats Available (before): ' || v_avail_seats
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: Train ID ' || p_train_id || ' not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Booking failed: ' || SQLERRM);
END Book_Ticket;
/

-- -------------------------------------------------------
-- Procedure 2: Cancel_Booking
-- Updates booking status to Cancelled and marks payment as Refunded.
-- Includes guard to prevent double-cancellation.
-- The cancel_trigger will automatically restore Available_Seats.
-- -------------------------------------------------------
CREATE OR REPLACE PROCEDURE Cancel_Booking (
    p_booking_id IN Booking.Booking_ID%TYPE
) AS
    v_status Booking.Booking_Status%TYPE;
BEGIN
    SELECT Booking_Status INTO v_status
    FROM Booking
    WHERE Booking_ID = p_booking_id;

    IF v_status = 'Cancelled' THEN
        DBMS_OUTPUT.PUT_LINE('Booking ' || p_booking_id || ' is already cancelled.');
    ELSE
        UPDATE Booking
        SET Booking_Status = 'Cancelled'
        WHERE Booking_ID = p_booking_id;

        UPDATE Payment
        SET Payment_Status = 'Refunded'
        WHERE Booking_ID = p_booking_id;

        DBMS_OUTPUT.PUT_LINE(
            'Booking ' || p_booking_id || ' cancelled successfully. Refund initiated.'
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: Booking ID ' || p_booking_id || ' not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Cancellation failed: ' || SQLERRM);
END Cancel_Booking;
/


-- ============================================================
-- SECTION 5: PL/SQL - FUNCTIONS
-- ============================================================

-- -------------------------------------------------------
-- Function 1: Calc_Fare
-- Computes total fare at a flat rate of Rs. 500 per seat.
-- Usage: SELECT Calc_Fare(3) FROM DUAL; → Returns 1500
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION Calc_Fare (
    seats IN NUMBER
) RETURN NUMBER IS
BEGIN
    RETURN seats * 500;
END Calc_Fare;
/

-- -------------------------------------------------------
-- Function 2: Get_Available_Seats
-- Returns real-time available seats for a given train
-- on a specific journey date, accounting for all existing
-- Confirmed and Waitlisted bookings on that date.
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION Get_Available_Seats (
    p_train_id     IN NUMBER,
    p_journey_date IN DATE
) RETURN NUMBER IS
    v_total_seats  NUMBER;
    v_booked_seats NUMBER;
BEGIN
    SELECT Total_Seats INTO v_total_seats
    FROM Train WHERE Train_ID = p_train_id;

    SELECT NVL(SUM(No_Of_Seats), 0) INTO v_booked_seats
    FROM Booking
    WHERE Train_ID       = p_train_id
      AND Journey_Date   = p_journey_date
      AND Booking_Status IN ('Confirmed', 'Waitlisted');

    RETURN v_total_seats - v_booked_seats;

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN -1;
END Get_Available_Seats;
/


-- ============================================================
-- SECTION 6: PL/SQL - TRIGGERS
-- ============================================================

-- -------------------------------------------------------
-- Trigger 1: cancel_trigger
-- Fires AFTER UPDATE on Booking when status changes to 'Cancelled'.
-- Automatically restores freed seats into Train.Available_Seats.
-- :OLD holds the pre-update values; the WHEN clause ensures
-- the trigger body executes only for cancellation updates.
-- -------------------------------------------------------
CREATE OR REPLACE TRIGGER cancel_trigger
AFTER UPDATE ON Booking
FOR EACH ROW
WHEN (NEW.Booking_Status = 'Cancelled')
BEGIN
    UPDATE Train
    SET Available_Seats = Available_Seats + :OLD.No_Of_Seats
    WHERE Train_ID = :OLD.Train_ID;
END;
/

-- -------------------------------------------------------
-- Trigger 2: before_booking_trigger
-- Fires BEFORE INSERT on Booking.
-- Validates that the journey date is not in the past.
-- Raises an application error if the date is invalid,
-- preventing the INSERT from completing.
-- -------------------------------------------------------
CREATE OR REPLACE TRIGGER before_booking_trigger
BEFORE INSERT ON Booking
FOR EACH ROW
BEGIN
    IF :NEW.Journey_Date < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Journey date ' || TO_CHAR(:NEW.Journey_Date, 'DD-MON-YYYY') ||
            ' is in the past. Booking rejected.'
        );
    END IF;
END;
/

-- -------------------------------------------------------
-- Trigger 3: booking_log_trigger
-- Fires AFTER INSERT on Booking.
-- Automatically logs every new booking into the Booking_Log
-- audit table with a timestamp and action description.
-- This provides a complete audit trail without any manual steps.
-- -------------------------------------------------------
CREATE OR REPLACE TRIGGER booking_log_trigger
AFTER INSERT ON Booking
FOR EACH ROW
BEGIN
    INSERT INTO Booking_Log (
        Log_ID, Booking_ID, Passenger_ID, Train_ID, Log_Time, Action
    ) VALUES (
        booking_log_seq.NEXTVAL,
        :NEW.Booking_ID,
        :NEW.Passenger_ID,
        :NEW.Train_ID,
        SYSTIMESTAMP,
        'New booking created with status: ' || :NEW.Booking_Status
    );
END;
/


-- ============================================================
-- SECTION 7: PL/SQL - CURSORS
-- ============================================================

-- -------------------------------------------------------
-- Cursor 1: Display all confirmed tickets for a given passenger
-- An explicit cursor with multi-table JOIN fetches ticket details.
-- Uses OPEN → LOOP → FETCH → EXIT WHEN → CLOSE pattern.
-- Set v_passenger_id to any valid Passenger_ID before running.
-- -------------------------------------------------------
DECLARE
    v_passenger_id   NUMBER := 1;   -- Change to query a different passenger
    v_passenger_name VARCHAR2(100);

    CURSOR ticket_cursor IS
        SELECT
            tk.Ticket_No,
            t.Train_Name,
            tk.Coach_No,
            tk.Seat_No,
            tk.Berth_Type,
            tk.Fare,
            b.Journey_Date,
            b.Class_Type
        FROM Ticket  tk
        JOIN Booking  b  ON tk.Booking_ID  = b.Booking_ID
        JOIN Train    t  ON b.Train_ID     = t.Train_ID
        WHERE b.Passenger_ID   = v_passenger_id
          AND b.Booking_Status = 'Confirmed'
        ORDER BY b.Journey_Date;

    ticket_rec ticket_cursor%ROWTYPE;
BEGIN
    SELECT Name INTO v_passenger_name
    FROM Passenger
    WHERE Passenger_ID = v_passenger_id;

    DBMS_OUTPUT.PUT_LINE('=== Ticket Details for: ' || v_passenger_name || ' ===');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    OPEN ticket_cursor;
    LOOP
        FETCH ticket_cursor INTO ticket_rec;
        EXIT WHEN ticket_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            'PNR: '   || ticket_rec.Ticket_No  ||
            ' | Train: ' || ticket_rec.Train_Name ||
            ' | Coach: ' || ticket_rec.Coach_No   ||
            ' | Seat: '  || ticket_rec.Seat_No    ||
            ' | Berth: ' || ticket_rec.Berth_Type ||
            ' | Class: ' || ticket_rec.Class_Type ||
            ' | Fare: Rs.' || ticket_rec.Fare     ||
            ' | Date: '  || TO_CHAR(ticket_rec.Journey_Date, 'DD-MON-YYYY')
        );
    END LOOP;
    CLOSE ticket_cursor;

    DBMS_OUTPUT.PUT_LINE('Total tickets fetched: ' || ticket_cursor%ROWCOUNT);
END;
/

-- -------------------------------------------------------
-- Cursor 2: Booking traversal - print all booking statuses
-- Simpler cursor that iterates the entire Booking table
-- and prints the ID and status of every booking.
-- -------------------------------------------------------
DECLARE
    CURSOR c1 IS
        SELECT Booking_ID, Booking_Status FROM Booking ORDER BY Booking_ID;
    rec c1%ROWTYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== All Bookings Status Summary ===');
    OPEN c1;
    LOOP
        FETCH c1 INTO rec;
        EXIT WHEN c1%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'Booking ID: ' || rec.Booking_ID ||
            '  |  Status: ' || rec.Booking_Status
        );
    END LOOP;
    CLOSE c1;
END;
/

-- -------------------------------------------------------
-- Cursor 3 (Analytical): Revenue summary per train using cursor
-- Iterates the result of a JOIN + GROUP BY via cursor,
-- and prints a formatted revenue report for each train.
-- -------------------------------------------------------
DECLARE
    CURSOR revenue_cursor IS
        SELECT
            t.Train_Name,
            COUNT(b.Booking_ID)  AS Total_Bookings,
            SUM(pay.Amount)      AS Total_Revenue
        FROM Train   t
        JOIN Booking b   ON t.Train_ID   = b.Train_ID
        JOIN Payment pay ON b.Booking_ID = pay.Booking_ID
        WHERE pay.Payment_Status = 'Success'
        GROUP BY t.Train_Name
        ORDER BY Total_Revenue DESC;

    v_name     VARCHAR2(100);
    v_bookings NUMBER;
    v_revenue  NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Train Revenue Report ===');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');
    OPEN revenue_cursor;
    LOOP
        FETCH revenue_cursor INTO v_name, v_bookings, v_revenue;
        EXIT WHEN revenue_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_name, 22) ||
            ' | Bookings: ' || v_bookings ||
            ' | Revenue: Rs.' || v_revenue
        );
    END LOOP;
    CLOSE revenue_cursor;
END;
/


-- ============================================================
-- SECTION 8: TRANSACTION MANAGEMENT
-- Demonstrates ACID-compliant multi-step booking transaction.
-- Uses SAVEPOINT for partial rollback capability.
-- ============================================================

BEGIN
    -- Step 1: Insert new booking for Ravi Patel on Bangalore Exp
    INSERT INTO Booking (
        Booking_ID, Passenger_ID, Train_ID,
        Source_Station_ID, Dest_Station_ID,
        Journey_Date, Booking_Date,
        Booking_Status, No_Of_Seats, Class_Type
    ) VALUES (
        9, 3, 105, 1, 6,
        DATE '2026-06-15', SYSDATE,
        'Confirmed', 1, '3A'
    );
    SAVEPOINT after_booking;

    -- Step 2: Issue the corresponding ticket
    INSERT INTO Ticket (Ticket_No, Booking_ID, Coach_No, Seat_No, Berth_Type, Fare)
    VALUES (5008, 9, 'B1', 5, 'LB', 1400.00);
    SAVEPOINT after_ticket;

    -- Step 3: Record the payment
    INSERT INTO Payment (
        Payment_ID, Booking_ID, Amount,
        Payment_Mode, Payment_DateTime,
        Payment_Status, Transaction_Ref_No
    ) VALUES (
        108, 9, 1400.00, 'UPI',
        SYSTIMESTAMP, 'Success', 'UPI20260501008'
    );

    -- All steps succeeded: commit the full transaction
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Transaction committed successfully. Booking ID: 9');

EXCEPTION
    WHEN OTHERS THEN
        -- Any failure: roll back to just after booking was inserted
        ROLLBACK TO after_booking;
        DBMS_OUTPUT.PUT_LINE('Transaction rolled back. Error: ' || SQLERRM);
END;
/


-- ============================================================
-- SECTION 9: SAMPLE PROCEDURE AND FUNCTION CALLS
-- ============================================================

-- Call Book_Ticket: Priya Singh books 1 SL seat on Chennai Express
BEGIN
    Book_Ticket(
        p_passenger_id    => 2,
        p_train_id        => 103,
        p_src_station_id  => 1,
        p_dest_station_id => 3,
        p_journey_date    => DATE '2026-06-01',
        p_class_type      => 'SL',
        p_no_seats        => 1
    );
END;
/

-- Call Cancel_Booking: Cancel booking #3
BEGIN
    Cancel_Booking(p_booking_id => 3);
END;
/

-- Use Calc_Fare function: fare for 4 seats
SELECT Calc_Fare(4) AS Fare_For_4_Seats FROM DUAL;

-- Use Get_Available_Seats function for Train 101 on 10-MAY-2026
SELECT
    Get_Available_Seats(101, DATE '2026-05-10') AS Available_On_Rajdhani
FROM DUAL;

-- Final COMMIT to persist everything
COMMIT;
