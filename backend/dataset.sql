-- ============================================
-- E-RAIL FULL DATASET (DML - INSERTS)
-- ============================================

-- ======================
-- STATION DATA
-- ======================

INSERT INTO Station VALUES (1, 'New Delhi', 'NDLS', 'New Delhi', 'Delhi');
INSERT INTO Station VALUES (2, 'Mumbai Central', 'BCT', 'Mumbai', 'Maharashtra');
INSERT INTO Station VALUES (3, 'Chennai Central', 'MAS', 'Chennai', 'Tamil Nadu');
INSERT INTO Station VALUES (4, 'Howrah Junction', 'HWH', 'Kolkata', 'West Bengal');
INSERT INTO Station VALUES (5, 'Amritsar Jn', 'ASR', 'Amritsar', 'Punjab');
INSERT INTO Station VALUES (6, 'Bangalore City', 'SBC', 'Bangalore', 'Karnataka');
INSERT INTO Station VALUES (7, 'Hyderabad Deccan', 'HYB', 'Hyderabad', 'Telangana');

-- ======================
-- TRAIN DATA
-- ======================

INSERT INTO Train VALUES (101,'Rajdhani Express','Superfast',500,1,2,
TO_TIMESTAMP('2026-05-10 16:00','YYYY-MM-DD HH24:MI'),
TO_TIMESTAMP('2026-05-11 08:00','YYYY-MM-DD HH24:MI'));

INSERT INTO Train VALUES (102,'Punjab Mail','Express',800,5,2,
TO_TIMESTAMP('2026-05-10 09:00','YYYY-MM-DD HH24:MI'),
TO_TIMESTAMP('2026-05-11 05:30','YYYY-MM-DD HH24:MI'));

INSERT INTO Train VALUES (103,'Chennai Express','Superfast',600,1,3,
TO_TIMESTAMP('2026-05-10 22:00','YYYY-MM-DD HH24:MI'),
TO_TIMESTAMP('2026-05-11 18:30','YYYY-MM-DD HH24:MI'));

INSERT INTO Train VALUES (104,'Howrah Mail','Express',750,1,4,
TO_TIMESTAMP('2026-05-10 23:55','YYYY-MM-DD HH24:MI'),
TO_TIMESTAMP('2026-05-12 07:00','YYYY-MM-DD HH24:MI'));

INSERT INTO Train VALUES (105,'Bangalore Exp','Superfast',550,1,6,
TO_TIMESTAMP('2026-05-10 20:30','YYYY-MM-DD HH24:MI'),
TO_TIMESTAMP('2026-05-11 14:00','YYYY-MM-DD HH24:MI'));

-- ======================
-- PASSENGER DATA
-- ======================

INSERT INTO Passenger VALUES (1,'Amit Sharma',35,'M','9876543210','[amit.sharma@email.com](mailto:amit.sharma@email.com)');
INSERT INTO Passenger VALUES (2,'Priya Singh',28,'F','9012345678','[priya.singh@email.com](mailto:priya.singh@email.com)');
INSERT INTO Passenger VALUES (3,'Ravi Patel',42,'M','9123456789','[ravi.patel@email.com](mailto:ravi.patel@email.com)');
INSERT INTO Passenger VALUES (4,'Sunita Rao',31,'F','9234567890','[sunita.rao@email.com](mailto:sunita.rao@email.com)');
INSERT INTO Passenger VALUES (5,'Arun Kumar',25,'M','9345678901','[arun.kumar@email.com](mailto:arun.kumar@email.com)');
INSERT INTO Passenger VALUES (6,'Meena Joshi',38,'F','9456789012','[meena.joshi@email.com](mailto:meena.joshi@email.com)');
INSERT INTO Passenger VALUES (7,'Vikram Das',55,'M','9567890123','[vikram.das@email.com](mailto:vikram.das@email.com)');

-- ======================
-- BOOKING DATA
-- ======================

INSERT INTO Booking VALUES (1,1,101,1,2,DATE '2026-05-10',DATE '2026-04-20','Confirmed',1,'3A');
INSERT INTO Booking VALUES (2,2,101,1,2,DATE '2026-05-10',DATE '2026-04-21','Confirmed',2,'SL');
INSERT INTO Booking VALUES (3,3,102,5,2,DATE '2026-05-10',DATE '2026-04-22','Waitlisted',1,'2A');
INSERT INTO Booking VALUES (4,4,103,1,3,DATE '2026-05-10',DATE '2026-04-18','Confirmed',1,'1A');
INSERT INTO Booking VALUES (5,5,104,1,4,DATE '2026-05-10',DATE '2026-04-25','Confirmed',2,'SL');
INSERT INTO Booking VALUES (6,6,105,1,6,DATE '2026-05-10',DATE '2026-04-19','Confirmed',1,'CC');
INSERT INTO Booking VALUES (7,7,102,5,2,DATE '2026-05-11',DATE '2026-04-23','Cancelled',1,'3A');
INSERT INTO Booking VALUES (8,1,103,1,3,DATE '2026-05-12',DATE '2026-04-20','Confirmed',1,'2A');

-- ======================
-- TICKET DATA
-- ======================

INSERT INTO Ticket VALUES (5001,1,'B2',42,'LB',1250.00);
INSERT INTO Ticket VALUES (5002,2,'S5',15,'SL',850.00);
INSERT INTO Ticket VALUES (5003,3,'A1',8,'UB',2100.00);
INSERT INTO Ticket VALUES (5004,4,'A1',1,'LB',3500.00);
INSERT INTO Ticket VALUES (5005,5,'S8',30,'SL',900.00);
INSERT INTO Ticket VALUES (5006,6,'C2',22,'WL',1800.00);
INSERT INTO Ticket VALUES (5007,8,'B3',11,'MB',2050.00);

-- ======================
-- PAYMENT DATA
-- ======================

INSERT INTO Payment VALUES (101,1,1250.00,'UPI',SYSTIMESTAMP,'Success','UPI20260420001');
INSERT INTO Payment VALUES (102,2,1700.00,'Card',SYSTIMESTAMP,'Success','CARD20260421002');
INSERT INTO Payment VALUES (103,3,2100.00,'Net Banking',SYSTIMESTAMP,'Success','NB20260422003');
INSERT INTO Payment VALUES (104,4,3500.00,'Card',SYSTIMESTAMP,'Success','CARD20260418004');
INSERT INTO Payment VALUES (105,5,1800.00,'UPI',SYSTIMESTAMP,'Success','UPI20260425005');
INSERT INTO Payment VALUES (106,6,1800.00,'Cash',SYSTIMESTAMP,'Success','CASH20260419006');
INSERT INTO Payment VALUES (107,8,2050.00,'UPI',SYSTIMESTAMP,'Success','UPI20260420007');

-- ======================
-- COMMIT
-- ======================

COMMIT;
