create database Airline;
drop database Airline
use Airline;
use master

-- Triggers:

-- BEFORE INSERT Trigger to Set Status to Pending:
GO
CREATE TRIGGER trg_before_insert_bookings
ON Bookings
INSTEAD OF INSERT
AS
BEGIN
    INSERT INTO Bookings (Bk_id, Passenger_id, Tkt_id, PaymentMethod, AmountPaid, Flight_id, Seat_No, BookingDate, Status)
    SELECT Bk_id, Passenger_id, Tkt_id, PaymentMethod, AmountPaid, Flight_id, Seat_No, BookingDate, 'Pending'
    FROM inserted;
END;

-- AFTER INSERT Trigger to Check AmountPaid and Update Status:
GO
CREATE TRIGGER trg_after_insert_bookings
ON Bookings
AFTER INSERT
AS
BEGIN
    DECLARE @Tkt_id VARCHAR(50);
    DECLARE @AmountPaid FLOAT;
    DECLARE @Price FLOAT;
    DECLARE @Bk_id VARCHAR(20);

    -- Fetch the required values from the inserted row
    SELECT @Tkt_id = i.Tkt_id, @AmountPaid = i.AmountPaid, @Bk_id = i.Bk_id
    FROM inserted i;

    -- Fetch the ticket price
    SELECT @Price = t.Price
    FROM Tickets t
    WHERE t.Tkt_id = @Tkt_id;

    -- Update the status based on the comparison
    IF @AmountPaid >= @Price
    BEGIN
        UPDATE Bookings
        SET Status = 'Reserved'
        WHERE Bk_id = @Bk_id;
    END
    ELSE
    BEGIN
        UPDATE Bookings
        SET Status = 'Cancelled'
        WHERE Bk_id = @Bk_id;
    END
END;

--AFTER UPDATE Trigger to Check AmountPaid and Update Status:
GO
CREATE TRIGGER trg_after_update_bookings
ON Bookings
AFTER UPDATE
AS
BEGIN
    DECLARE @Tkt_id VARCHAR(50);
    DECLARE @AmountPaid FLOAT;
    DECLARE @Price FLOAT;
    DECLARE @Bk_id VARCHAR(20);

    -- Fetch the required values from the updated row
    SELECT @Tkt_id = i.Tkt_id, @AmountPaid = i.AmountPaid, @Bk_id = i.Bk_id
    FROM inserted i
    JOIN deleted d ON i.Bk_id = d.Bk_id
    WHERE i.AmountPaid <> d.AmountPaid; -- Only consider rows where AmountPaid was updated

    -- Fetch the ticket price
    SELECT @Price = t.Price
    FROM Tickets t
    WHERE t.Tkt_id = @Tkt_id;

    -- Update the status based on the comparison
    IF @AmountPaid >= @Price
    BEGIN
        UPDATE Bookings
        SET Status = 'Reserved'
        WHERE Bk_id = @Bk_id;
    END
    ELSE
    BEGIN
        UPDATE Bookings
        SET Status = 'Cancelled'
        WHERE Bk_id = @Bk_id;
    END
END;

--Seat no null, if status is set to cancelled
GO
CREATE TRIGGER UpdateSeatNoOnCancel
ON Bookings
AFTER UPDATE
AS
BEGIN
  IF TRIGGER_NESTLEVEL() > 1
     RETURN
     
  UPDATE b
  SET b.Seat_No = NULL,
      b.AmountPaid = 0
  FROM Bookings b
  INNER JOIN inserted i ON b.Bk_id = i.Bk_id
  WHERE i.Status = 'cancelled';
END

--on insert, if the ticket class is economy then different price range and for business class a different price range:
GO
CREATE TRIGGER assign_ticket_price_on_insert
ON Tickets
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Tickets (Tkt_id, Class, Ticket_from, Ticket_to, Price)
    SELECT 
        i.Tkt_id,
        i.Class,
        i.Ticket_from,
        i.Ticket_to,
        CASE 
            WHEN i.Class = 'Economy' THEN FLOOR(RAND()*(30000-10000+1))+10000
            WHEN i.Class = 'Business' THEN FLOOR(RAND()*(65000-31000+1))+31000
            ELSE NULL
        END AS Price
    FROM inserted i;
END;

-- if we update a ticket price, then price range is kept in mind too
GO
CREATE TRIGGER check_ticket_price_before_update
ON Tickets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted WHERE Class = 'Economy' AND Price NOT IN (10000, 15000, 25000, 30000))
    BEGIN
        RAISERROR ('Economy class price must be one of the following: 10000, 15000, 25000, 30000', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM inserted WHERE Class = 'Business' AND Price NOT IN (31000, 35000, 40000, 45000, 50000, 65000))
    BEGIN
        RAISERROR ('Business class price must be one of the following: 31000, 35000, 40000, 45000, 50000, 65000', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;


--setting schedule time
GO
CREATE TRIGGER trg_UpdateFlightScheduleOnBooking
ON dbo.Bookings
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BookingDate DATETIME,
            @Flight_id VARCHAR(250),
            @DepartureTime DATETIME,
            @ArrivalTime DATETIME;

    -- Fetch the BookingDate and Flight_id from the inserted row
    SELECT @BookingDate = i.BookingDate,
           @Flight_id = i.Flight_id
    FROM inserted i;

    -- Calculate the new DepartureTime and ArrivalTime
    SET @DepartureTime = DATEADD(HOUR, 5, @BookingDate);
    SET @ArrivalTime = DATEADD(HOUR, 2, @DepartureTime);

    -- Update the Flight_Schedule table with the new times
    UPDATE dbo.Flight_Schedule
    SET DepartureTime = @DepartureTime,
        ArrivalTime = @ArrivalTime
    WHERE Flight_id = @Flight_id;
END;

--booking deleted when a passenger deleted from the passengers table:
go
CREATE TRIGGER trg_DeleteBookingsOnPassengerDelete
ON Passengers
INSTEAD OF DELETE
AS
BEGIN
    -- Delete all booking records associated with the passenger being deleted
    DELETE FROM Bookings
    WHERE Passenger_id IN (SELECT Passenger_id FROM DELETED);

    -- Now delete the passenger record
    DELETE FROM Passengers
    WHERE Passenger_id IN (SELECT Passenger_id FROM DELETED);
END;

-- if a ticket deleted from the tickets table , booking deleted

GO
CREATE TRIGGER delete_ticket_trigger
ON Tickets
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @tkt_id_var VARCHAR(50);

    -- Store the Tkt_id to be deleted
    SELECT @tkt_id_var = deleted.Tkt_id FROM deleted;

    -- Delete the corresponding bookings records
    DELETE FROM Bookings
    WHERE Tkt_id = @tkt_id_var;

    -- Delete the ticket record
    DELETE FROM Tickets
    WHERE Tkt_id = @tkt_id_var;
END;


--if flight deleted, first in booking tables, flight id is set to null and booking status is also set to cancelled 
go
CREATE TRIGGER delete_flight_trigger
ON Flight_Schedule
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @flight_id_var VARCHAR(250);

    -- Store the flight_id to be deleted
    SELECT @flight_id_var = deleted.Flight_id FROM deleted;

    -- Update the corresponding bookings records
    UPDATE Bookings
    SET Flight_id = NULL,
        Status = 'Cancelled'
    WHERE Flight_id = @flight_id_var;

    -- Update any staff assignments related to the deleted flight
    UPDATE StaffAssignments
    SET Flight_id = NULL
    WHERE Flight_id = @flight_id_var;
END;

--if a staff deleted, then before deleting it, it's assignment in the staff assignments table is set to null
go
CREATE TRIGGER delete_staff_trigger
ON Crew_Staff
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @staff_id_var VARCHAR(10);

    -- Store the staff_id to be deleted
    SELECT @staff_id_var = deleted.Staff_id FROM deleted;

    -- Update the corresponding staff assignments records
    UPDATE StaffAssignments
    SET Staff_id = NULL
    WHERE Staff_id = @staff_id_var;

    -- Delete the staff record
    DELETE FROM Crew_Staff
    WHERE Staff_id = @staff_id_var;
END;

-- set admin id null from the schedule tables first before admin record gets deleted:
go
CREATE TRIGGER delete_admin_trigger
ON Admins
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @admin_id_var VARCHAR(250);

    -- Store the Admin_id to be deleted
    SELECT @admin_id_var = deleted.Admin_id FROM deleted;

    -- Update the corresponding flight schedule records
    UPDATE Flight_Schedule
    SET Admin_id = NULL
    WHERE Admin_id = @admin_id_var;

    -- Delete the admin record
    DELETE FROM Admins
    WHERE Admin_id = @admin_id_var;
END;

--set aircraft id to null in schedules before  if its record is deleted from the aircrafts table 
go
CREATE TRIGGER delete_aircraft_trigger
ON Aircrafts
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ac_id_var VARCHAR(10);

    -- Store the Ac_id to be deleted
    SELECT @ac_id_var = deleted.Ac_id FROM deleted;

    -- Update the corresponding flight schedule records
    UPDATE Flight_Schedule
    SET Ac_id = NULL
    WHERE Ac_id = @ac_id_var;

    -- Delete the aircraft record
    DELETE FROM Aircrafts
    WHERE Ac_id = @ac_id_var;
END;
go

--automatically assigning staff assignment date according to the flight departure time
CREATE TRIGGER SetAssignmentDate
ON StaffAssignments
AFTER INSERT
AS
BEGIN
    UPDATE sa
    SET sa.AssignmentDate = DATEADD(hour, -5, fs.DepartureTime)
    FROM StaffAssignments sa
    INNER JOIN inserted i ON sa.Assg_id = i.Assg_id
    INNER JOIN Flight_Schedule fs ON sa.Flight_id = fs.Flight_id
    WHERE sa.AssignmentDate IS NULL; -- Only update if AssignmentDate is NULL
END;

go
--log tables:

-- Create Passengers_Log table
CREATE TABLE Passengers_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Passenger_id VARCHAR(10),
    FName VARCHAR(100),
    LName VARCHAR(100),
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Address VARCHAR(255),
    DateOfBirth DATE,
    Gender VARCHAR(10),
    Cnic VARCHAR(50),
    passport_no VARCHAR(10)
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_passenger_inserts
ON Passengers
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Passengers_Log (Operation, Operation_Timestamp, UserName, Passenger_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender, Cnic, passport_no)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Passenger_id, 
        FName, 
        LName, 
        Email, 
        Phone, 
        Address, 
        DateOfBirth, 
        Gender, 
        Cnic, 
        passport_no
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_passenger_updates
ON Passengers
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Passengers_Log (Operation, Operation_Timestamp, UserName, Passenger_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender, Cnic, passport_no)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Passenger_id, 
        inserted.FName, 
        inserted.LName, 
        inserted.Email, 
        inserted.Phone, 
        inserted.Address, 
        inserted.DateOfBirth, 
        inserted.Gender, 
        inserted.Cnic, 
        inserted.passport_no
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Passenger_id = deleted.Passenger_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_passenger_deletes
ON Passengers
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Passengers_Log (Operation, Operation_Timestamp, UserName, Passenger_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender, Cnic, passport_no)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Passenger_id, 
        FName, 
        LName, 
        Email, 
        Phone, 
        Address, 
        DateOfBirth, 
        Gender, 
        Cnic, 
        passport_no
    FROM 
        deleted;
END;
GO

-- Create Aircrafts_Log table
CREATE TABLE Aircrafts_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Ac_id VARCHAR(10),
    Aircraft_Name VARCHAR(100),
    Model VARCHAR(100),
    Capacity INT
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_aircraft_inserts
ON Aircrafts
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Aircrafts_Log (Operation, Operation_Timestamp, UserName, Ac_id, Aircraft_Name, Model, Capacity)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Ac_id, 
        Aircraft_Name, 
        Model, 
        Capacity
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_aircraft_updates
ON Aircrafts
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Aircrafts_Log (Operation, Operation_Timestamp, UserName, Ac_id, Aircraft_Name, Model, Capacity)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Ac_id, 
        inserted.Aircraft_Name, 
        inserted.Model, 
        inserted.Capacity
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Ac_id = deleted.Ac_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_aircraft_deletes
ON Aircrafts
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Aircrafts_Log (Operation, Operation_Timestamp, UserName, Ac_id, Aircraft_Name, Model, Capacity)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Ac_id, 
        Aircraft_Name, 
        Model, 
        Capacity
    FROM 
        deleted;
END;
GO

-- Create Tickets_Log table
CREATE TABLE Tickets_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Tkt_id VARCHAR(50),
    Class VARCHAR(50),
    Ticket_from VARCHAR(100),
    Ticket_to VARCHAR(100),
    Price FLOAT
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_ticket_inserts
ON Tickets
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Tickets_Log (Operation, Operation_Timestamp, UserName, Tkt_id, Class, Ticket_from, Ticket_to, Price)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Tkt_id, 
        Class, 
        Ticket_from, 
        Ticket_to, 
        Price
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_ticket_updates
ON Tickets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Tickets_Log (Operation, Operation_Timestamp, UserName, Tkt_id, Class, Ticket_from, Ticket_to, Price)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Tkt_id, 
        inserted.Class, 
        inserted.Ticket_from, 
        inserted.Ticket_to, 
        inserted.Price
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Tkt_id = deleted.Tkt_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_ticket_deletes
ON Tickets
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Tickets_Log (Operation, Operation_Timestamp, UserName, Tkt_id, Class, Ticket_from, Ticket_to, Price)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Tkt_id, 
        Class, 
        Ticket_from, 
        Ticket_to, 
        Price
    FROM 
        deleted;
END;
GO

-- Create Admins_Log table
CREATE TABLE Admins_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Admin_id VARCHAR(250),
    FName VARCHAR(100),
    LName VARCHAR(100),
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Address VARCHAR(255),
    DateOfBirth DATE,
    Gender VARCHAR(10)
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_admin_inserts
ON Admins
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Admins_Log (Operation, Operation_Timestamp, UserName, Admin_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Admin_id, 
        FName, 
        LName, 
        Email, 
        Phone, 
        Address, 
        DateOfBirth, 
        Gender
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_admin_updates
ON Admins
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Admins_Log (Operation, Operation_Timestamp, UserName, Admin_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Admin_id, 
        inserted.FName, 
        inserted.LName, 
        inserted.Email, 
        inserted.Phone, 
        inserted.Address, 
        inserted.DateOfBirth, 
        inserted.Gender
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Admin_id = deleted.Admin_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_admin_deletes
ON Admins
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Admins_Log (Operation, Operation_Timestamp, UserName, Admin_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Admin_id, 
        FName, 
        LName, 
        Email, 
        Phone, 
        Address, 
        DateOfBirth, 
        Gender
    FROM 
        deleted;
END;
GO

-- Create Crew_Staff_Log table
CREATE TABLE Crew_Staff_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Staff_id VARCHAR(10),
    FName VARCHAR(100),
    LName VARCHAR(100),
    Designation VARCHAR(100),
    DateOfBirth DATE,
    Gender VARCHAR(10),
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Address VARCHAR(255)
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_crew_staff_inserts
ON Crew_Staff
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Crew_Staff_Log (Operation, Operation_Timestamp, UserName, Staff_id, FName, LName, Designation, DateOfBirth, Gender, Email, Phone, Address)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Staff_id, 
        FName, 
        LName, 
        Designation, 
        DateOfBirth, 
        Gender, 
        Email, 
        Phone, 
        Address
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_crew_staff_updates
ON Crew_Staff
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Crew_Staff_Log (Operation, Operation_Timestamp, UserName, Staff_id, FName, LName, Designation, DateOfBirth, Gender, Email, Phone, Address)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Staff_id, 
        inserted.FName, 
        inserted.LName, 
        inserted.Designation, 
        inserted.DateOfBirth, 
        inserted.Gender, 
        inserted.Email, 
        inserted.Phone, 
        inserted.Address
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Staff_id = deleted.Staff_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_crew_staff_deletes
ON Crew_Staff
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Crew_Staff_Log (Operation, Operation_Timestamp, UserName, Staff_id, FName, LName, Designation, DateOfBirth, Gender, Email, Phone, Address)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Staff_id, 
        FName, 
        LName, 
        Designation, 
        DateOfBirth, 
        Gender, 
        Email, 
        Phone, 
        Address
    FROM 
        deleted;
END;
GO

-- Create Flight_Schedule_Log table
CREATE TABLE Flight_Schedule_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Flight_id VARCHAR(250),
    DepartureTime DATETIME,
    ArrivalTime DATETIME,
    Ac_id VARCHAR(10),
    Admin_id VARCHAR(250)
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_flight_schedule_inserts
ON Flight_Schedule
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Flight_Schedule_Log (Operation, Operation_Timestamp, UserName, Flight_id, DepartureTime, ArrivalTime, Ac_id, Admin_id)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Flight_id, 
        DepartureTime, 
        ArrivalTime, 
        Ac_id, 
        Admin_id
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_flight_schedule_updates
ON Flight_Schedule
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Flight_Schedule_Log (Operation, Operation_Timestamp, UserName, Flight_id, DepartureTime, ArrivalTime, Ac_id, Admin_id)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Flight_id, 
        inserted.DepartureTime, 
        inserted.ArrivalTime, 
        inserted.Ac_id, 
        inserted.Admin_id
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Flight_id = deleted.Flight_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_flight_schedule_deletes
ON Flight_Schedule
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Flight_Schedule_Log (Operation, Operation_Timestamp, UserName, Flight_id, DepartureTime, ArrivalTime, Ac_id, Admin_id)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Flight_id, 
        DepartureTime, 
        ArrivalTime, 
        Ac_id, 
        Admin_id
    FROM 
        deleted;
END;
GO

-- Create StaffAssignments_Log table
GO
CREATE TABLE StaffAssignments_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Assg_id VARCHAR(50),
    Flight_id VARCHAR(250),
    Staff_id VARCHAR(10),
	AssignmentDate DATETIME
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_staff_assignments_inserts
ON StaffAssignments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO StaffAssignments_Log (Operation, Operation_Timestamp, UserName, Assg_id, Flight_id, Staff_id,AssignmentDate)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Assg_id, 
        Flight_id, 
        Staff_id,
		AssignmentDate
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_staff_assignments_updates
ON StaffAssignments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO StaffAssignments_Log (Operation, Operation_Timestamp, UserName, Assg_id, Flight_id, Staff_id,AssignmentDate)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Assg_id, 
        inserted.Flight_id, 
        inserted.Staff_id,
		inserted.AssignmentDate
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Assg_id = deleted.Assg_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_staff_assignments_deletes
ON StaffAssignments
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO StaffAssignments_Log (Operation, Operation_Timestamp, UserName, Assg_id, Flight_id, Staff_id,AssignmentDate)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Assg_id, 
        Flight_id, 
        Staff_id,
		AssignmentDate
    FROM 
        deleted;
END;
GO

-- Create Bookings_Log table
CREATE TABLE Bookings_Log (
    Log_id INT IDENTITY(1,1) PRIMARY KEY,
    Operation VARCHAR(10),
    Operation_Timestamp DATETIME DEFAULT GETDATE(),
    UserName VARCHAR(100),
    Bk_id VARCHAR(20),
    Passenger_id VARCHAR(10),
    Tkt_id VARCHAR(50),
    PaymentMethod VARCHAR(50),
    AmountPaid FLOAT,
    Flight_id VARCHAR(250),
    Seat_No VARCHAR(10),
    BookingDate DATETIME,
    Status VARCHAR(50)
);
GO

-- Create trigger for INSERT
CREATE TRIGGER log_bookings_inserts
ON Bookings
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Bookings_Log (Operation, Operation_Timestamp, UserName, Bk_id, Passenger_id, Tkt_id, PaymentMethod, AmountPaid, Flight_id, Seat_No, BookingDate, Status)
    SELECT 
        'INSERT', 
        GETDATE(), 
        SYSTEM_USER, 
        Bk_id, 
        Passenger_id, 
        Tkt_id, 
        PaymentMethod, 
        AmountPaid, 
        Flight_id, 
        Seat_No, 
        BookingDate, 
        Status
    FROM 
        inserted;
END;
GO

-- Create trigger for UPDATE
CREATE TRIGGER log_bookings_updates
ON Bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Bookings_Log (Operation, Operation_Timestamp, UserName, Bk_id, Passenger_id, Tkt_id, PaymentMethod, AmountPaid, Flight_id, Seat_No, BookingDate, Status)
    SELECT 
        'UPDATE', 
        GETDATE(), 
        SYSTEM_USER, 
        inserted.Bk_id, 
        inserted.Passenger_id, 
        inserted.Tkt_id, 
        inserted.PaymentMethod, 
        inserted.AmountPaid, 
        inserted.Flight_id, 
        inserted.Seat_No, 
        inserted.BookingDate, 
        inserted.Status
    FROM 
        inserted
    JOIN 
        deleted 
    ON 
        inserted.Bk_id = deleted.Bk_id;
END;
GO

-- Create trigger for DELETE
CREATE TRIGGER log_bookings_deletes
ON Bookings
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Bookings_Log (Operation, Operation_Timestamp, UserName, Bk_id, Passenger_id, Tkt_id, PaymentMethod, AmountPaid, Flight_id, Seat_No, BookingDate, Status)
    SELECT 
        'DELETE', 
        GETDATE(), 
        SYSTEM_USER, 
        Bk_id, 
        Passenger_id, 
        Tkt_id, 
        PaymentMethod, 
        AmountPaid, 
        Flight_id, 
        Seat_No, 
        BookingDate, 
        Status
    FROM 
        deleted;
END;
GO


--schema
CREATE TABLE Passengers (
    Passenger_id VARCHAR(10) PRIMARY KEY,
    FName VARCHAR(100),
    LName VARCHAR(100),    
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Address VARCHAR(255),
    DateOfBirth DATE,
    Gender VARCHAR(10),
    Cnic VARCHAR(50),
    passport_no VARCHAR(10)
);

CREATE TABLE Aircrafts (
    Ac_id VARCHAR(10) PRIMARY KEY,
    Aircraft_Name VARCHAR(100),
    Model VARCHAR(100),
    Capacity INT
);

CREATE TABLE Tickets (
    Tkt_id VARCHAR(50) PRIMARY KEY,
    Class VARCHAR(50),
    Ticket_from VARCHAR(100),
    Ticket_to VARCHAR(100),
    Price FLOAT
);

CREATE TABLE Admins (
    Admin_id VARCHAR(250) PRIMARY KEY,
    FName VARCHAR(100),
    LName VARCHAR(100),
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Address VARCHAR(255),
    DateOfBirth DATE,
    Gender VARCHAR(10)
);

CREATE TABLE Crew_Staff (
    Staff_id VARCHAR(10) PRIMARY KEY,
    FName VARCHAR(100),
    LName VARCHAR(100),
    Designation VARCHAR(100),
    DateOfBirth DATE,
    Gender VARCHAR(10),
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Address VARCHAR(255)
);

CREATE TABLE Flight_Schedule (
    Flight_id VARCHAR(250) PRIMARY KEY,
    DepartureTime DATETIME,
    ArrivalTime DATETIME,
    Ac_id VARCHAR(10),
    Admin_id VARCHAR(250),
    FOREIGN KEY (Ac_id) REFERENCES Aircrafts(Ac_id),
    FOREIGN KEY (Admin_id) REFERENCES Admins(Admin_id)
);

CREATE TABLE StaffAssignments (
    Assg_id VARCHAR(50) PRIMARY KEY,
    Flight_id VARCHAR(250),
    Staff_id VARCHAR(10),
    AssignmentDate DATETIME,
    FOREIGN KEY (Staff_id) REFERENCES Crew_Staff(Staff_id),
    FOREIGN KEY (Flight_id) REFERENCES Flight_Schedule(Flight_id)
);

CREATE TABLE Bookings (
    Bk_id VARCHAR(20) PRIMARY KEY,
    Passenger_id VARCHAR(10),
    Tkt_id VARCHAR(50),
    PaymentMethod VARCHAR(50),
    AmountPaid FLOAT,
    Flight_id VARCHAR(250),
    Seat_No VARCHAR(10),
    BookingDate DATETIME,
    Status VARCHAR(50),
    FOREIGN KEY (Flight_id) REFERENCES Flight_Schedule(Flight_id),
    FOREIGN KEY (Passenger_id) REFERENCES Passengers(Passenger_id),
    FOREIGN KEY (Tkt_id) REFERENCES Tickets(Tkt_id)
);

--data check:
select * from passengers
select * from Aircrafts
select * from Admins
select * from Tickets
select * from bookings
select * from Crew_Staff
select * from FLight_Schedule
select * from StaffAssignments
drop table Tickets

drop table Bookings
drop table FLight_Schedule
drop table Tickets
drop table Admins
drop database Airline;


--non clustered indexex:

-- users
CREATE INDEX idx_passengers_cnic ON Passengers (Cnic asc); 
go
--admins
CREATE INDEX IX_Admins_Email ON Admins (Email asc);
CREATE INDEX IX_Admins_Phone ON Admins (Phone asc);
go
-- Crew_Staff
CREATE  INDEX IX_Crew_Staff_Email ON Crew_Staff (Email asc);
CREATE INDEX IX_Crew_Staff_Phone ON Crew_Staff (Phone asc);
go
--tickets
CREATE INDEX idx_tickets_ticket_from ON Tickets (
Ticket_from asc,
Ticket_to asc);
CREATE INDEX idx_tickets_price ON Tickets (Price asc);
go

--Staff Assignment
CREATE INDEX idx_staff_assignments_staff_id ON StaffAssignments (Staff_id asc);
CREATE INDEX idx_staff_assignments_flight_id ON StaffAssignments (Flight_id asc);
CREATE INDEX idx_staff_assignments_assignmentDate ON StaffAssignments (AssignmentDate asc);
go

-- Flight_Schedule
CREATE INDEX IX_Flight_Schedule_DepartureTime ON Flight_Schedule (DepartureTime);
CREATE INDEX IX_Flight_Schedule_ArrivalTime ON Flight_Schedule (ArrivalTime);
CREATE INDEX IX_Flight_Schedule_Ac_id ON Flight_Schedule (Ac_id);
CREATE INDEX IX_Flight_Schedule_Admin_id ON Flight_Schedule (Admin_id);
go
-- Bookings
CREATE INDEX IX_Bookings_Passenger_id ON Bookings (Passenger_id);
CREATE INDEX IX_Bookings_Tkt_id ON Bookings (Tkt_id);
CREATE INDEX IX_Bookings_Flight_id ON Bookings (Flight_id);
go

--daily reports:

--Number of Flights Scheduled Today
go
CREATE VIEW DailyFlights AS
SELECT COUNT(DISTINCT FS.Flight_id) AS NumberOfFlights
FROM Flight_Schedule FS
JOIN Bookings B ON FS.Flight_id = B.Flight_id
WHERE CAST(FS.DepartureTime AS DATE) = CAST(GETDATE() AS DATE)
  AND B.Status = 'Reserved';

--Number of Bookings Made Today
go
CREATE VIEW DailyBookings AS
SELECT COUNT(*) AS NumberOfBookings
FROM Bookings
WHERE CAST(BookingDate AS DATE) = CAST(GETDATE() AS DATE)
AND Status = 'Reserved';

--Total Revenue Generated Today
go
CREATE VIEW DailyRevenue AS
SELECT SUM(AmountPaid) AS TotalRevenue
FROM Bookings
WHERE CAST(BookingDate AS DATE) = CAST(GETDATE() AS DATE)
AND Status = 'Reserved';

-- List of Passengers for Today's Flights with Departure and Arrival Times
go
CREATE VIEW DailyPassengers AS
SELECT 
    P.Passenger_id, 
    P.FName, 
    P.LName, 
    P.Email, 
    P.Phone, 
    F.Flight_id, 
    F.DepartureTime, 
    F.ArrivalTime
FROM 
    Passengers P
JOIN 
    Bookings B ON P.Passenger_id = B.Passenger_id
JOIN 
    Flight_Schedule F ON B.Flight_id = F.Flight_id
WHERE 
    CAST(F.DepartureTime AS DATE) = CAST(GETDATE() AS DATE ) AND B.Status = 'Reserved';

-- Number of Flights Departed and Arrived Today:
go
CREATE VIEW DailyDepartures AS
SELECT COUNT(*) AS NumberOfDepartures
FROM Flight_Schedule
WHERE CAST(DepartureTime AS DATE) = CAST(GETDATE() AS DATE);

go
CREATE VIEW DailyArrivals AS
SELECT COUNT(*) AS NumberOfArrivals
FROM Flight_Schedule
WHERE CAST(ArrivalTime AS DATE) = CAST(GETDATE() AS DATE);




--Stored Procedure for Daily Report
go
create PROCEDURE GenerateDailyReport
AS
BEGIN
    -- Number of Flights Scheduled Today
    PRINT 'Number of Flights Scheduled Today:';
    SELECT * FROM DailyFlights;
    
    -- Number of Bookings Made Today
    PRINT 'Number of Bookings Made Today:';
    SELECT * FROM DailyBookings;
    
    -- Total Revenue Generated Today
    PRINT 'Total Revenue Generated Today:';
    SELECT * FROM DailyRevenue;
    
    -- List of Passengers for Today's Flights
    PRINT 'List of Passengers for Today''s Flights:';
    SELECT * FROM DailyPassengers;

    -- Number of Flights Departed Today
    PRINT 'Number of Flights Departed Today:';
    SELECT * FROM DailyDepartures;

    -- Number of Flights Arrived Today
    PRINT 'Number of Flights Arrived Today:';
    SELECT * FROM DailyArrivals;

END;
GO

EXEC GenerateDailyReport;
go

--denormalized table:
CREATE TABLE dbo.DenormalizedBaseTable (
    DenormalizedViewId INT IDENTITY(1,1) PRIMARY KEY,
    Booking_id VARCHAR(20),
    Passenger_id VARCHAR(10),
    Passenger_FName VARCHAR(100),
    Passenger_LName VARCHAR(100),
    Passenger_Email VARCHAR(100),
    Passenger_Phone VARCHAR(20),
    Passenger_Address VARCHAR(255),
    Passenger_DateOfBirth DATE,
    Passenger_Gender VARCHAR(10),
    Passenger_Cnic VARCHAR(50),
    Passenger_PassportNo VARCHAR(10),
    Ticket_id VARCHAR(50),
    Ticket_Class VARCHAR(50),
    Ticket_from VARCHAR(100),
    Ticket_to VARCHAR(100),
    Ticket_Price FLOAT,
    Payment_Method VARCHAR(50),
    Amount_Paid FLOAT,
    Flight_id VARCHAR(250),
    Seat_Number VARCHAR(10),
    Booking_Date DATETIME,
    Booking_Status VARCHAR(50),
    Departure_Time DATETIME,
    Arrival_Time DATETIME,
    Aircraft_id VARCHAR(10),
    Aircraft_Name VARCHAR(100),
    Aircraft_Model VARCHAR(100),
    Aircraft_Capacity INT,
    Assigned_Staff_Designation VARCHAR(100),
    Staff_id VARCHAR(10),
	AssignmentDate DATETIME
);
go
--inserting data into the denormalized table
INSERT INTO dbo.DenormalizedBaseTable (
    Booking_id, 
    Passenger_id, 
    Passenger_FName, 
    Passenger_LName, 
    Passenger_Email, 
    Passenger_Phone, 
    Passenger_Address, 
    Passenger_DateOfBirth, 
    Passenger_Gender, 
    Passenger_Cnic, 
    Passenger_PassportNo, 
    Ticket_id, 
    Ticket_Class, 
    Ticket_from, 
    Ticket_to, 
    Ticket_Price, 
    Payment_Method, 
    Amount_Paid, 
    Flight_id, 
    Seat_Number, 
    Booking_Date, 
    Booking_Status, 
    Departure_Time, 
    Arrival_Time, 
    Aircraft_id, 
    Aircraft_Name, 
    Aircraft_Model, 
    Aircraft_Capacity, 
    Assigned_Staff_Designation, 
    Staff_id,
    AssignmentDate
)
SELECT 
    Bk.Bk_id AS Booking_id,
    P.Passenger_id,
    P.FName AS Passenger_FName,
    P.LName AS Passenger_LName,
    P.Email AS Passenger_Email,
    P.Phone AS Passenger_Phone,
    P.Address AS Passenger_Address,
    P.DateOfBirth AS Passenger_DateOfBirth,
    P.Gender AS Passenger_Gender,
    P.Cnic AS Passenger_Cnic,
    P.passport_no AS Passenger_PassportNo,
    T.Tkt_id AS Ticket_id,
    T.Class AS Ticket_Class,
    T.Ticket_from AS Ticket_from,
    T.Ticket_to AS Ticket_to,
    T.Price AS Ticket_Price,
    Bk.PaymentMethod AS Payment_Method,
    Bk.AmountPaid AS Amount_Paid,
    Bk.Flight_id AS Flight_id,
    Bk.Seat_No AS Seat_Number,
    Bk.BookingDate AS Booking_Date,
    Bk.Status AS Booking_Status,
    FS.DepartureTime AS Departure_Time,
    FS.ArrivalTime AS Arrival_Time,
    FS.Ac_id AS Aircraft_id,
    A.Aircraft_Name,
    A.Model AS Aircraft_Model,
    A.Capacity AS Aircraft_Capacity,
    CS.Designation AS Assigned_Staff_Designation,
    CS.Staff_id AS Staff_id,
    DATEADD(HOUR, -5, FS.DepartureTime) AS AssignmentDate -- Set the AssignmentDate
FROM dbo.Bookings Bk
JOIN dbo.Passengers P ON Bk.Passenger_id = P.Passenger_id
JOIN dbo.Tickets T ON Bk.Tkt_id = T.Tkt_id
JOIN dbo.Flight_Schedule FS ON Bk.Flight_id = FS.Flight_id
JOIN dbo.Aircrafts A ON FS.Ac_id = A.Ac_id
JOIN dbo.StaffAssignments SA ON FS.Flight_id = SA.Flight_id
JOIN dbo.Crew_Staff CS ON SA.Staff_id = CS.Staff_id;
GO

--mateerialized/indexed view:
CREATE VIEW dbo.DenormalizedIndexedView
WITH SCHEMABINDING
AS
SELECT 
    DenormalizedViewId,
    Booking_id,
    Passenger_id,
    Passenger_FName,
    Passenger_LName,
    Passenger_Email,
    Passenger_Phone,
    Passenger_Address,
    Passenger_DateOfBirth,
    Passenger_Gender,
    Passenger_Cnic,
    Passenger_PassportNo,
    Ticket_id,
    Ticket_Class,
    Ticket_from,
    Ticket_to,
    Ticket_Price,
    Payment_Method,
    Amount_Paid,
    Flight_id,
    Seat_Number,
    Booking_Date,
    Booking_Status,
    Departure_Time,
    Arrival_Time,
    Aircraft_id,
    Aircraft_Name,
    Aircraft_Model,
    Aircraft_Capacity,
    Assigned_Staff_Designation,
    Staff_id,
    AssignmentDate
FROM dbo.DenormalizedBaseTable;
GO
CREATE UNIQUE CLUSTERED INDEX IX_DenormalizedIndexedView ON dbo.DenormalizedIndexedView (DenormalizedViewId);
GO
select * from DenormalizedIndexedView
go
drop view DenormalizedIndexedView
DROP TABLE DenormalizedBaseTable
SELECT * FROM BookingS

--analytical reports:

--Monthly Revenue Report:
CREATE VIEW MonthlyRevenue AS
WITH UniqueBookings AS (
    SELECT 
        DISTINCT Booking_id, 
        Amount_Paid, 
        Booking_Date
    FROM 
        dbo.DenormalizedIndexedView
    WHERE
        Booking_Status = 'reserved'
)
SELECT 
    YEAR(Booking_Date) AS Year, 
    MONTH(Booking_Date) AS Month, 
    SUM(Amount_Paid) AS TotalRevenue
FROM 
    UniqueBookings
GROUP BY 
    YEAR(Booking_Date), 
    MONTH(Booking_Date);
go
--Passenger Demographics Report:
CREATE VIEW PassengerDemographics AS
SELECT 
    Passenger_Gender,
    COUNT(DISTINCT Passenger_id) AS NumberOfPassengers,
    AVG(DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE())) AS AverageAge
FROM 
    dbo.DenormalizedIndexedView
GROUP BY 
    Passenger_Gender;
go
--Flight Capacity Utilization Report(reserved ones only):
CREATE VIEW FlightCapacityUtilization AS
SELECT 
    Flight_id, 
    Aircraft_id, 
    Aircraft_Capacity, 
    COUNT(DISTINCT Booking_id) AS BookedSeats, 
    (COUNT(DISTINCT Booking_id) * 1.0 / Aircraft_Capacity) * 100 AS UtilizationPercentage
FROM 
    dbo.DenormalizedIndexedView
WHERE 
    Booking_Status = 'reserved'
GROUP BY 
    Flight_id, 
    Aircraft_id, 
    Aircraft_Capacity;
go

--Class Distribution Report:
CREATE VIEW ClassDistribution AS
SELECT 
    Ticket_Class, 
    COUNT(DISTINCT Booking_id) AS NumberOfTickets
FROM 
    dbo.DenormalizedIndexedView
WHERE
    Booking_Status = 'reserved'
GROUP BY 
    Ticket_Class;
go

--Age Group Distribution Report:
CREATE VIEW AgeGroupDistribution AS
SELECT 
    CASE 
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) < 18 THEN 'Under 18'
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) BETWEEN 18 AND 25 THEN '18-25'
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) BETWEEN 26 AND 35 THEN '26-35'
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) BETWEEN 36 AND 50 THEN '36-50'
        ELSE 'Above 50'
    END AS AgeGroup,
    COUNT(DISTINCT Passenger_id) AS NumberOfPassengers
FROM 
    dbo.DenormalizedIndexedView
WHERE
    Booking_Status = 'reserved'
GROUP BY 
    CASE 
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) < 18 THEN 'Under 18'
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) BETWEEN 18 AND 25 THEN '18-25'
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) BETWEEN 26 AND 35 THEN '26-35'
        WHEN DATEDIFF(YEAR, Passenger_DateOfBirth, GETDATE()) BETWEEN 36 AND 50 THEN '36-50'
        ELSE 'Above 50'
    END;
go

--Popular Payment Methods Report:
CREATE VIEW PopularPaymentMethods AS
SELECT 
    Payment_Method, 
    COUNT(DISTINCT Booking_id) AS NumberOfBookings
FROM 
    dbo.DenormalizedIndexedView
WHERE
    Booking_Status = 'reserved'
GROUP BY 
    Payment_Method;
go

--Flights by Booking Status:
CREATE VIEW FlightsByBookingStatus AS
SELECT 
    Booking_Status, 
    COUNT(DISTINCT Booking_id) AS NumberOfFlights
FROM 
    dbo.DenormalizedIndexedView
GROUP BY 
    Booking_Status;

go

CREATE PROCEDURE GenerateAnalyticalReports
AS
BEGIN
	SELECT * FROM MonthlyRevenue ORDER BY Year, Month;

	SELECT * FROM PassengerDemographics

	SELECT * FROM FlightCapacityUtilization

	SELECT * FROM ClassDistribution

	SELECT * FROM AgeGroupDistribution

	SELECT * FROM PopularPaymentMethods ORDER BY NumberOfBookings DESC;

	SELECT * FROM FlightsByBookingStatus
END;
go

EXEC GenerateAnalyticalReports;
go


--CRUD Procedures
-- CRUD procedures for Passengers table
CREATE PROCEDURE InsertPassenger
    @Passenger_id VARCHAR(10),
    @FName VARCHAR(100),
    @LName VARCHAR(100),
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(255),
    @DateOfBirth DATE,
    @Gender VARCHAR(10),
    @Cnic VARCHAR(50),
    @passport_no VARCHAR(10)
AS
BEGIN
    INSERT INTO Passengers (Passenger_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender, Cnic, passport_no)
    VALUES (@Passenger_id, @FName, @LName, @Email, @Phone, @Address, @DateOfBirth, @Gender, @Cnic, @passport_no);
END;
GO

CREATE PROCEDURE UpdatePassenger
    @Passenger_id VARCHAR(10),
    @FName VARCHAR(100),
    @LName VARCHAR(100),
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(255),
    @DateOfBirth DATE,
    @Gender VARCHAR(10),
    @Cnic VARCHAR(50),
    @passport_no VARCHAR(10)
AS
BEGIN
    UPDATE Passengers
    SET FName = @FName,
        LName = @LName,
        Email = @Email,
        Phone = @Phone,
        Address = @Address,
        DateOfBirth = @DateOfBirth,
        Gender = @Gender,
        Cnic = @Cnic,
        passport_no = @passport_no
    WHERE Passenger_id = @Passenger_id;
END;
GO

CREATE PROCEDURE DeletePassenger
    @Passenger_id VARCHAR(10)
AS
BEGIN
    DELETE FROM Passengers WHERE Passenger_id = @Passenger_id;
END;
GO

CREATE PROCEDURE SelectAllPassengers
AS
BEGIN
    SELECT * FROM Passengers;
END;
GO

-- Procedure to check a specific passenger record
CREATE PROCEDURE CheckPassenger
    @Passenger_id VARCHAR(10)
AS
BEGIN
    SELECT * FROM Passengers WHERE Passenger_id = @Passenger_id;
END;
GO

-- CRUD procedures for Aircrafts table
CREATE PROCEDURE InsertAircraft
    @Ac_id VARCHAR(10),
    @Aircraft_Name VARCHAR(100),
    @Model VARCHAR(100),
    @Capacity INT
AS
BEGIN
    INSERT INTO Aircrafts (Ac_id, Aircraft_Name, Model, Capacity)
    VALUES (@Ac_id, @Aircraft_Name, @Model, @Capacity);
END;
GO

CREATE PROCEDURE UpdateAircraft
    @Ac_id VARCHAR(10),
    @Aircraft_Name VARCHAR(100),
    @Model VARCHAR(100),
    @Capacity INT
AS
BEGIN
    UPDATE Aircrafts
    SET Aircraft_Name = @Aircraft_Name,
        Model = @Model,
        Capacity = @Capacity
    WHERE Ac_id = @Ac_id;
END;
GO

CREATE PROCEDURE DeleteAircraft
    @Ac_id VARCHAR(10)
AS
BEGIN
    DELETE FROM Aircrafts WHERE Ac_id = @Ac_id;
END;
GO

CREATE PROCEDURE SelectAllAircrafts
AS
BEGIN
    SELECT * FROM Aircrafts;
END;
GO

-- Procedure to check a specific aircraft record
CREATE PROCEDURE CheckAircraft
    @Ac_id VARCHAR(10)
AS
BEGIN
    SELECT * FROM Aircrafts WHERE Ac_id = @Ac_id;
END;
GO

-- CRUD procedures for Tickets table
CREATE PROCEDURE InsertTicket
    @Tkt_id VARCHAR(50),
    @Class VARCHAR(50),
    @Ticket_from VARCHAR(100),
    @Ticket_to VARCHAR(100),
    @Price FLOAT
AS
BEGIN
    INSERT INTO Tickets (Tkt_id, Class, Ticket_from, Ticket_to, Price)
    VALUES (@Tkt_id, @Class, @Ticket_from, @Ticket_to, @Price);
END;
GO

CREATE PROCEDURE UpdateTicket
    @Tkt_id VARCHAR(50),
    @Class VARCHAR(50),
    @Ticket_from VARCHAR(100),
    @Ticket_to VARCHAR(100),
    @Price FLOAT
AS
BEGIN
    UPDATE Tickets
    SET Class = @Class,
        Ticket_from = @Ticket_from,
        Ticket_to = @Ticket_to,
        Price = @Price
    WHERE Tkt_id = @Tkt_id;
END;
GO

CREATE PROCEDURE DeleteTicket
    @Tkt_id VARCHAR(50)
AS
BEGIN
    DELETE FROM Tickets WHERE Tkt_id = @Tkt_id;
END;
GO

CREATE PROCEDURE SelectAllTickets
AS
BEGIN
    SELECT * FROM Tickets;
END;
GO

-- Procedure to check a specific ticket record
CREATE PROCEDURE CheckTicket
    @Tkt_id VARCHAR(50)
AS
BEGIN
    SELECT * FROM Tickets WHERE Tkt_id = @Tkt_id;
END;
GO

-- CRUD procedures for Admins table
CREATE PROCEDURE InsertAdmin
    @Admin_id VARCHAR(250),
    @FName VARCHAR(100),
    @LName VARCHAR(100),
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(255),
    @DateOfBirth DATE,
    @Gender VARCHAR(10)
AS
BEGIN
    INSERT INTO Admins (Admin_id, FName, LName, Email, Phone, Address, DateOfBirth, Gender)
    VALUES (@Admin_id, @FName, @LName, @Email, @Phone, @Address, @DateOfBirth, @Gender);
END;
GO

CREATE PROCEDURE UpdateAdmin
    @Admin_id VARCHAR(250),
    @FName VARCHAR(100),
    @LName VARCHAR(100),
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(255),
    @DateOfBirth DATE,
    @Gender VARCHAR(10)
AS
BEGIN
    UPDATE Admins
    SET FName = @FName,
        LName = @LName,
        Email = @Email,
        Phone = @Phone,
        Address = @Address,
        DateOfBirth = @DateOfBirth,
        Gender = @Gender
    WHERE Admin_id = @Admin_id;
END;
GO

CREATE PROCEDURE DeleteAdmin
    @Admin_id VARCHAR(250)
AS
BEGIN
    DELETE FROM Admins WHERE Admin_id = @Admin_id;
END;
GO

CREATE PROCEDURE SelectAllAdmins
AS
BEGIN
    SELECT * FROM Admins;
END;
GO

-- Procedure to check a specific admin record
CREATE PROCEDURE CheckAdmin
    @Admin_id VARCHAR(250)
AS
BEGIN
    SELECT * FROM Admins WHERE Admin_id = @Admin_id;
END;
GO

-- CRUD procedures for Crew_Staff table
CREATE PROCEDURE InsertCrewStaff
    @Staff_id VARCHAR(10),
    @FName VARCHAR(100),
    @LName VARCHAR(100),
    @Designation VARCHAR(100),
    @DateOfBirth DATE,
    @Gender VARCHAR(10),
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(255)
AS
BEGIN
    INSERT INTO Crew_Staff (Staff_id, FName, LName, Designation, DateOfBirth, Gender, Email, Phone, Address)
    VALUES (@Staff_id, @FName, @LName, @Designation, @DateOfBirth, @Gender, @Email, @Phone, @Address);
END;
GO

CREATE PROCEDURE UpdateCrewStaff
    @Staff_id VARCHAR(10),
    @FName VARCHAR(100),
    @LName VARCHAR(100),
    @Designation VARCHAR(100),
    @DateOfBirth DATE,
    @Gender VARCHAR(10),
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(255)
AS
BEGIN
    UPDATE Crew_Staff
    SET FName = @FName,
        LName = @LName,
        Designation = @Designation,
        DateOfBirth = @DateOfBirth,
        Gender = @Gender,
        Email = @Email,
        Phone = @Phone,
        Address = @Address
    WHERE Staff_id = @Staff_id;
END;
GO

CREATE PROCEDURE DeleteCrewStaff
    @Staff_id VARCHAR(10)
AS
BEGIN
    DELETE FROM Crew_Staff WHERE Staff_id = @Staff_id;
END;
GO

CREATE PROCEDURE SelectAllCrewStaff
AS
BEGIN
    SELECT * FROM Crew_Staff;
END;
GO

-- Procedure to check a specific crew staff record
CREATE PROCEDURE CheckCrewStaff
    @Staff_id VARCHAR(10)
AS
BEGIN
    SELECT * FROM Crew_Staff WHERE Staff_id = @Staff_id;
END;
GO

-- CRUD procedures for Flight_Schedule table
CREATE PROCEDURE InsertFlightSchedule
    @Flight_id VARCHAR(250),
    @DepartureTime DATETIME,
    @ArrivalTime DATETIME,
    @Ac_id VARCHAR(10),
    @Admin_id VARCHAR(250)
AS
BEGIN
    INSERT INTO Flight_Schedule (Flight_id, DepartureTime, ArrivalTime, Ac_id, Admin_id)
    VALUES (@Flight_id, @DepartureTime, @ArrivalTime, @Ac_id, @Admin_id);
END;
GO

CREATE PROCEDURE UpdateFlightSchedule
    @Flight_id VARCHAR(250),
    @DepartureTime DATETIME,
    @ArrivalTime DATETIME,
    @Ac_id VARCHAR(10),
    @Admin_id VARCHAR(250)
AS
BEGIN
    UPDATE Flight_Schedule
    SET DepartureTime = @DepartureTime,
        ArrivalTime = @ArrivalTime,
        Ac_id = @Ac_id,
        Admin_id = @Admin_id
    WHERE Flight_id = @Flight_id;
END;
GO

CREATE PROCEDURE DeleteFlightSchedule
    @Flight_id VARCHAR(250)
AS
BEGIN
    DELETE FROM Flight_Schedule WHERE Flight_id = @Flight_id;
END;
GO

CREATE PROCEDURE SelectAllFlightSchedules
AS
BEGIN
    SELECT * FROM Flight_Schedule;
END;
GO

-- Procedure to check a specific flight schedule record
CREATE PROCEDURE CheckFlightSchedule
    @Flight_id VARCHAR(250)
AS
BEGIN
    SELECT * FROM Flight_Schedule WHERE Flight_id = @Flight_id;
END;
GO

-- CRUD procedures for StaffAssignments table
CREATE PROCEDURE InsertStaffAssignment
    @Assg_id VARCHAR(50),
    @Flight_id VARCHAR(250),
    @Staff_id VARCHAR(10),
    @AssignmentDate DATETIME
AS
BEGIN
    INSERT INTO StaffAssignments (Assg_id, Flight_id, Staff_id, AssignmentDate)
    VALUES (@Assg_id, @Flight_id, @Staff_id, @AssignmentDate);
END;
GO

CREATE PROCEDURE UpdateStaffAssignment
    @Assg_id VARCHAR(50),
    @Flight_id VARCHAR(250),
    @Staff_id VARCHAR(10),
    @AssignmentDate DATETIME
AS
BEGIN
    UPDATE StaffAssignments
    SET Flight_id = @Flight_id,
        Staff_id = @Staff_id,
        AssignmentDate = @AssignmentDate
    WHERE Assg_id = @Assg_id;
END;
GO

CREATE PROCEDURE DeleteStaffAssignment
    @Assg_id VARCHAR(50)
AS
BEGIN
    DELETE FROM StaffAssignments WHERE Assg_id = @Assg_id;
END;
GO

CREATE PROCEDURE SelectAllStaffAssignments
AS
BEGIN
    SELECT * FROM StaffAssignments;
END;
GO

-- Procedure to check a specific staff assignment record
CREATE PROCEDURE CheckStaffAssignment
    @Assg_id VARCHAR(50)
AS
BEGIN
    SELECT * FROM StaffAssignments WHERE Assg_id = @Assg_id;
END;
GO

-- CRUD procedures for Bookings table
CREATE PROCEDURE InsertBooking
    @Bk_id VARCHAR(20),
    @Passenger_id VARCHAR(10),
    @Tkt_id VARCHAR(50),
    @PaymentMethod VARCHAR(50),
    @AmountPaid FLOAT,
    @Flight_id VARCHAR(250),
    @Seat_No VARCHAR(10),
    @BookingDate DATETIME,
    @Status VARCHAR(50)
AS
BEGIN
    INSERT INTO Bookings (Bk_id, Passenger_id, Tkt_id, PaymentMethod, AmountPaid, Flight_id, Seat_No, BookingDate, Status)
    VALUES (@Bk_id, @Passenger_id, @Tkt_id, @PaymentMethod, @AmountPaid, @Flight_id, @Seat_No, @BookingDate, @Status);
END;
GO

CREATE PROCEDURE UpdateBooking
    @Bk_id VARCHAR(20),
    @Passenger_id VARCHAR(10),
    @Tkt_id VARCHAR(50),
    @PaymentMethod VARCHAR(50),
    @AmountPaid FLOAT,
    @Flight_id VARCHAR(250),
    @Seat_No VARCHAR(10),
    @BookingDate DATETIME,
    @Status VARCHAR(50)
AS
BEGIN
    UPDATE Bookings
    SET Passenger_id = @Passenger_id,
        Tkt_id = @Tkt_id,
        PaymentMethod = @PaymentMethod,
        AmountPaid = @AmountPaid,
        Flight_id = @Flight_id,
        Seat_No = @Seat_No,
        BookingDate = @BookingDate,
        Status = @Status
    WHERE Bk_id = @Bk_id;
END;
GO

CREATE PROCEDURE DeleteBooking
    @Bk_id VARCHAR(20)
AS
BEGIN
    DELETE FROM Bookings WHERE Bk_id = @Bk_id;
END;
GO

CREATE PROCEDURE SelectAllBookings
AS
BEGIN
    SELECT * FROM Bookings;
END;
GO

-- Procedure to check a specific booking record
CREATE PROCEDURE CheckBooking
    @Bk_id VARCHAR(20)
AS
BEGIN
    SELECT * FROM Bookings WHERE Bk_id = @Bk_id;
END;
GO

-- Test all CRUD procedures
-- Test Passengers CRUD
EXEC InsertPassenger 'P001', 'John', 'Doe', 'john@example.com', '1234567890', '123 Main St', '1990-01-01', 'Male', '12345', 'AB1234567';
EXEC UpdatePassenger 'P001', 'Johnny', 'Doe', 'johnny@example.com', '0987654321', '456 Elm St', '1990-01-01', 'Male', '54321', 'CD9876543';
EXEC DeletePassenger 'P001';
EXEC SelectAllPassengers;
EXEC CheckPassenger 'P001';
-- Test Aircrafts CRUD
EXEC InsertAircraft 'A001', 'Boeing 747', '747-400', 416;
EXEC UpdateAircraft 'A001', 'Boeing 747', '747-800', 524;
EXEC DeleteAircraft 'A001';
EXEC SelectAllAircrafts;
EXEC CheckAircraft 'A001';

-- Test Tickets CRUD
EXEC InsertTicket 'T000000001', 'Business', 'New York', 'London', 1500.00;
EXEC UpdateTicket 'T001', 'First Class', 'New York', 'London', 2000.00;
EXEC DeleteTicket 'T001';
EXEC SelectAllTickets;
EXEC CheckTicket 'T001';

-- Test Admins CRUD
EXEC InsertAdmin 'ADM001', 'Admin', 'User', 'admin@example.com', '1234567890', '789 Park Ave', '1980-01-01', 'Male';
EXEC UpdateAdmin 'ADM001', 'Admin', 'Admin', 'admin@example.com', '0987654321', '789 Park Ave', '1980-01-01', 'Male';
EXEC DeleteAdmin 'ADM001';
EXEC SelectAllAdmins;
EXEC CheckAdmin 'ADM001';

-- Test Crew_Staff CRUD
EXEC InsertCrewStaff 'CS001', 'Jane', 'Doe', 'Flight Attendant', '1985-01-01', 'Female', 'jane@example.com', '1234567890', '456 Pine St';
EXEC UpdateCrewStaff 'CS001', 'Jane', 'Smith', 'Senior Flight Attendant', '1985-01-01', 'Female', 'jane@example.com', '0987654321', '456 Maple St';
EXEC DeleteCrewStaff 'CS001';
EXEC SelectAllCrewStaff;
EXEC CheckCrewStaff 'CS001';

-- Test Flight_Schedule CRUD
DECLARE @AdminId VARCHAR(250) = 'ADM001';
DECLARE @AircraftId VARCHAR(10) = 'A001';
EXEC InsertFlightSchedule 'FL001', '2024-06-01 08:00:00', '2024-06-01 12:00:00', @AircraftId, @AdminId;
EXEC UpdateFlightSchedule 'FL001', '2024-06-01 09:00:00', '2024-06-01 13:00:00', @AircraftId, @AdminId;
EXEC DeleteFlightSchedule 'FL001';
EXEC SelectAllFlightSchedules;
EXEC CheckFlightSchedule 'FL001';

-- Test StaffAssignments CRUD
EXEC InsertStaffAssignment 'SA001', 'FL001', 'CS001', '2024-06-01 07:00:00';
EXEC UpdateStaffAssignment 'SA001', 'FL002', 'CS002', '2024-06-01 08:00:00';
EXEC DeleteStaffAssignment 'SA001';
EXEC SelectAllStaffAssignments;
EXEC CheckStaffAssignment 'SA001';

-- Test Bookings CRUD
DECLARE @PassengerId VARCHAR(10) = 'P009999';
DECLARE @TicketId VARCHAR(50) = 'T000001';
DECLARE @FlightId VARCHAR(250) = 'FL0KKK01';
EXEC InsertBooking 'BK001', @PassengerId, @TicketId, 'Credit Card', 500.00, @FlightId, 'A1', '2024-06-01 10:00:00', 'Confirmed';
EXEC UpdateBooking 'BK001', @PassengerId, @TicketId, 'Credit Card', 600.00, @FlightId, 'A2', '2024-06-01 11:00:00', 'Cancelled';
EXEC DeleteBooking 'BK001';
EXEC SelectAllBookings;
EXEC CheckBooking 'BK001';


--procedure reports:

--Passenger Booking Summary:
CREATE PROCEDURE GetPassengerBookingSummary
AS
BEGIN
    SELECT 
        p.Passenger_id, 
        p.FName, 
        p.LName, 
        COUNT(b.Bk_id) AS TotalBookings, 
        SUM(b.AmountPaid) AS TotalAmountPaid
    FROM 
        Passengers p
    LEFT JOIN 
        Bookings b ON p.Passenger_id = b.Passenger_id
    WHERE 
        b.Status = 'reserved'
    GROUP BY 
        p.Passenger_id, 
        p.FName, 
        p.LName
    ORDER BY 
        TotalAmountPaid DESC;
END;
GO


--Flight Schedule and Crew Assignment
CREATE PROCEDURE GetFlightScheduleAndCrew
AS
BEGIN
    SELECT 
        fs.Flight_id, 
        fs.DepartureTime, 
        fs.ArrivalTime, 
        a.Aircraft_Name, 
        ad.FName AS AdminFirstName, 
        ad.LName AS AdminLastName,
        cs.FName AS CrewFirstName, 
        cs.LName AS CrewLastName, 
        cs.Designation
    FROM 
        Flight_Schedule fs
    JOIN 
        Aircrafts a ON fs.Ac_id = a.Ac_id
    JOIN 
        Admins ad ON fs.Admin_id = ad.Admin_id
    JOIN 
        StaffAssignments sa ON fs.Flight_id = sa.Flight_id
    JOIN 
        Crew_Staff cs ON sa.Staff_id = cs.Staff_id
    WHERE 
        fs.DepartureTime IS NOT NULL AND fs.ArrivalTime IS NOT NULL
    ORDER BY 
        fs.DepartureTime;
END;
GO

--Revenue Breakdown by Passenger Class
CREATE PROCEDURE GetRevenueBreakdownByPassengerClass
AS
BEGIN
    SELECT 
        t.Class,
        COUNT(b.Bk_id) AS TotalBookings,
        SUM(b.AmountPaid) AS TotalRevenue
    FROM 
        Bookings b
    JOIN 
        Tickets t ON b.Tkt_id = t.Tkt_id
    WHERE 
        b.Status = 'reserved'
    GROUP BY 
        t.Class
    ORDER BY 
        TotalRevenue DESC;
END;
go


exec GetPassengerBookingSummary
EXEC GetRevenueBreakdownByPassengerClass
exec  GetFlightScheduleAndCrew