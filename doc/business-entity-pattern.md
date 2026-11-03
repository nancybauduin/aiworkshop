# ABL Business Entity Architecture Pattern

## Overview

The Business Entity pattern provides a standardized, maintainable approach to data access in OpenEdge ABL applications. It separates UI logic from database operations through a layered architecture that promotes reusability, testability, and consistency across the application.

## Architecture Layers

### 1. UI Layer (Windows/Forms)
- **Responsibility**: User interaction and presentation
- **Access**: Never directly accesses database tables
- **Communication**: Calls Business Entity methods with datasets

### 2. Business Entity Layer
- **Responsibility**: Data access, business rules, validation
- **Inheritance**: Extends `OpenEdge.BusinessLogic.BusinessEntity`
- **Management**: Instantiated through EntityFactory (singleton pattern)

### 3. Database Layer
- **Responsibility**: Persistent storage
- **Access**: Only through data-sources attached to business entities

## Key Components

### EntityFactory (Singleton Pattern)

**Purpose**: Centralized management of business entity lifecycle

**Pattern**:
```abl
CLASS business.EntityFactory:
    /* Singleton instance */
    VAR PRIVATE STATIC EntityFactory objInstance.
    
    /* Entity instances */
    VAR PRIVATE CustomerEntity objCustomerEntityInstance.
    
    /* Private constructor prevents direct instantiation */
    CONSTRUCTOR PRIVATE EntityFactory():
    END CONSTRUCTOR.
    
    /* Public factory method */
    METHOD PUBLIC STATIC EntityFactory GetInstance():
        IF objInstance = ? THEN
            objInstance = NEW EntityFactory().
        RETURN objInstance.
    END METHOD.
    
    /* Entity getters with lazy initialization */
    METHOD PUBLIC CustomerEntity GetCustomerEntity():
        IF objCustomerEntityInstance = ? THEN
            objCustomerEntityInstance = NEW CustomerEntity().
        RETURN objCustomerEntityInstance.
    END METHOD.
END CLASS.
```

**Benefits**:
- Single source of truth for entity instances
- Prevents memory waste from duplicate objects
- Enables centralized cleanup and testing

### Dataset Definition (.i Include Files)

**Purpose**: Defines temp-tables and datasets for data transfer

**Pattern**:
```abl
/* Define temp-table with BEFORE-TABLE for change tracking */
DEFINE TEMP-TABLE ttCustomer BEFORE-TABLE bttCustomer
    FIELD CustNum AS INTEGER INITIAL "0" LABEL "Cust Num"
    FIELD Name AS CHARACTER LABEL "Name"
    FIELD Address AS CHARACTER LABEL "Address"
    /* ... additional fields ... */
    INDEX CustNum IS PRIMARY UNIQUE CustNum ASCENDING.

/* Define dataset containing the temp-table */
DEFINE DATASET dsCustomer FOR ttCustomer.
```

**Key Points**:
- `BEFORE-TABLE` enables change tracking for updates
- Temp-table fields match database table structure
- Primary index mirrors database primary key
- Shared via include file for consistency

### Business Entity Class

**Purpose**: Encapsulates all data operations for a specific entity

**Pattern**:
```abl
CLASS business.CustomerEntity INHERITS BusinessEntity USE-WIDGET-POOL:
    
    /* Include dataset definition */
    {business/CustomerDataset.i}
    
    /* Define data sources - one per database table */
    DEFINE DATA-SOURCE srcCustomer FOR Customer.
    
    CONSTRUCTOR PUBLIC CustomerEntity():
        /* Pass dataset handle to parent class */
        SUPER(DATASET dsCustomer:HANDLE).

        /* Create array of data source handles */
        VAR HANDLE[1] hDataSourceArray = DATA-SOURCE srcCustomer:HANDLE.
        VAR CHARACTER[1] cSkipListArray = [""].
        
        /* Set parent class properties */
        THIS-OBJECT:ProDataSource = hDataSourceArray.
        THIS-OBJECT:SkipList = cSkipListArray.
    END CONSTRUCTOR.
    
    /* Business methods follow... */
    
END CLASS.
```

**Critical Requirements**:
- Must inherit from `OpenEdge.BusinessLogic.BusinessEntity`
- Dataset handle passed to SUPER() constructor
- Data-source handles assigned to ProDataSource property
- SkipList array matches data-source array length

## Standard CRUD Operations

### Read (Query) Operations

**Pattern**:
```abl
METHOD PUBLIC LOGICAL GetCustomerByNumber(INPUT ipiCustNum AS INTEGER,
                                          OUTPUT DATASET dsCustomer):
    VAR CHARACTER cFilter.
    VAR LOGICAL lFound = FALSE.
    
    /* Build WHERE clause for database query */
    cFilter = "WHERE Customer.CustNum = " + STRING(ipiCustNum).
    
    /* Parent class ReadData() executes query and fills temp-table */
    THIS-OBJECT:ReadData(cFilter).

    /* Check if data was found */
    lFound = CAN-FIND(FIRST ttCustomer).
    
    RETURN lFound.
END METHOD.
```

**Key Points**:
- Use `OUTPUT DATASET` parameter (NOT `BY-REFERENCE`)
- Build filter as string with WHERE clause
- Call parent's `ReadData()` method
- Verify results using temp-table
- Return success/failure indicator

**Why NOT BY-REFERENCE for OUTPUT DATASET**:
- `BusinessEntity.ReadData()` fills the internal ProDataSet handle
- OUTPUT without BY-REFERENCE automatically copies data back to caller
- BY-REFERENCE can create handle mismatch issues
- The OUTPUT mechanism is the expected pattern for this architecture

### Create Operations

**Pattern**:
```abl
METHOD PUBLIC VOID CreateCustomer(INPUT-OUTPUT DATASET dsCustomer):
    /* Caller populates temp-table with new record */
    /* Parent class handles database insert */
    THIS-OBJECT:CreateData(DATASET dsCustomer BY-REFERENCE).
END METHOD.
```

**Usage from UI**:
```abl
/* Create new record in temp-table */
CREATE ttCustomer.
ASSIGN 
    ttCustomer.Name = "New Customer"
    ttCustomer.CustNum = 12345.

/* Call entity to persist */
objCustomerEntity:CreateCustomer(DATASET dsCustomer BY-REFERENCE).
```

### Update Operations

**Pattern**:
```abl
METHOD PUBLIC VOID UpdateCustomer(INPUT-OUTPUT DATASET dsCustomer):
    /* Parent class detects changes and updates database */
    THIS-OBJECT:UpdateData(DATASET dsCustomer BY-REFERENCE).
END METHOD.
```

**Usage from UI with Validation**:
```abl
/* Fetch existing customer */
lFound = objCustomerEntity:GetCustomerByNumber(iCustNum, OUTPUT DATASET dsCustomer).

IF lFound THEN DO:
    FIND FIRST ttCustomer.
    
    /* Enable change tracking */
    TEMP-TABLE ttCustomer:TRACKING-CHANGES = TRUE.
    
    /* Modify data */
    ttCustomer.Name = "Updated Name".
    
    /* Validate before saving */
    isValid = objCustomerEntity:ValidateCustomer(
        INPUT-OUTPUT DATASET dsCustomer BY-REFERENCE, 
        OUTPUT cErrorMessage
    ).
    
    IF isValid THEN
        /* Save changes */
        objCustomerEntity:UpdateCustomer(INPUT-OUTPUT DATASET dsCustomer BY-REFERENCE).
    ELSE
        MESSAGE cErrorMessage VIEW-AS ALERT-BOX.
END.
```

**Critical Steps**:
1. Fetch current data using OUTPUT DATASET
2. Enable TRACKING-CHANGES on temp-table
3. Modify temp-table fields
4. Validate changes
5. Call UpdateData() with BY-REFERENCE

### Delete Operations

**Pattern**:
```abl
METHOD PUBLIC VOID DeleteCustomer(INPUT-OUTPUT DATASET dsCustomer):
    /* Parent class processes deletion */
    THIS-OBJECT:DeleteData(DATASET dsCustomer BY-REFERENCE).
END METHOD.
```

**Usage from UI**:
```abl
/* Fetch customer to delete */
lFound = objCustomerEntity:GetCustomerByNumber(iCustNum, OUTPUT DATASET dsCustomer).

IF lFound THEN DO:
    /* Enable change tracking */
    TEMP-TABLE ttCustomer:TRACKING-CHANGES = TRUE.
    
    FIND FIRST ttCustomer.
    
    /* Mark for deletion */
    DELETE ttCustomer.
    
    /* Execute delete in database */
    objCustomerEntity:DeleteCustomer(INPUT-OUTPUT DATASET dsCustomer BY-REFERENCE).
END.
```

## Validation Pattern

**Pattern**:
```abl
METHOD PUBLIC LOGICAL ValidateCustomer(INPUT-OUTPUT DATASET dsCustomer,
                                     OUTPUT errorMessage AS CHARACTER):
    VAR LOGICAL isValid = TRUE.
    
    /* Find the record to validate */
    FIND FIRST ttCustomer NO-ERROR.
    IF AVAILABLE ttCustomer THEN DO:
        /* Check business rules */
        IF ttCustomer.Name = "" THEN DO:
            isValid = FALSE.
            errorMessage = "Customer name cannot be empty".
        END.
        
        /* Additional validation rules... */
        IF ttCustomer.CreditLimit < 0 THEN DO:
            isValid = FALSE.
            errorMessage = "Credit limit cannot be negative".
        END.
    END.
    
    RETURN isValid.
END METHOD.
```

**Best Practices**:
- Always validate before Create/Update operations
- Return specific error messages for UI display
- Check both required fields and business rules
- Use INPUT-OUTPUT DATASET BY-REFERENCE for validation

## Multi-Table Entities

For entities spanning multiple database tables (e.g., Order + OrderLine):

**Pattern**:
```abl
CLASS business.OrderEntity INHERITS BusinessEntity:
    
    {business/OrderDataset.i}
    
    /* Define data source for each table */
    DEFINE DATA-SOURCE srcOrder FOR Order.
    DEFINE DATA-SOURCE srcOrderLine FOR OrderLine.
    
    CONSTRUCTOR PUBLIC OrderEntity():
        SUPER(DATASET dsOrder:HANDLE).
        
        /* Array size matches number of tables */
        VAR HANDLE[2] hDataSourceArray.
        VAR CHARACTER[2] cSkipListArray.
        
        /* Assign data sources in order matching dataset */
        hDataSourceArray[1] = DATA-SOURCE srcOrder:HANDLE.
        hDataSourceArray[2] = DATA-SOURCE srcOrderLine:HANDLE.
        
        cSkipListArray[1] = "".
        cSkipListArray[2] = "".
        
        THIS-OBJECT:ProDataSource = hDataSourceArray.
        THIS-OBJECT:SkipList = cSkipListArray.
    END CONSTRUCTOR.
    
END CLASS.
```

**Dataset Definition**:
```abl
DEFINE TEMP-TABLE ttOrder BEFORE-TABLE bttOrder
    FIELD OrderNum AS INTEGER
    /* ... fields ... */
    INDEX OrderNum IS PRIMARY UNIQUE OrderNum.

DEFINE TEMP-TABLE ttOrderLine BEFORE-TABLE bttOrderLine
    FIELD OrderNum AS INTEGER
    FIELD LineNum AS INTEGER
    /* ... fields ... */
    INDEX OrderLine IS PRIMARY UNIQUE OrderNum LineNum.

/* Define parent-child relationship */
DEFINE DATASET dsOrder FOR ttOrder, ttOrderLine
    DATA-RELATION OrderLines FOR ttOrder, ttOrderLine
        RELATION-FIELDS(OrderNum, OrderNum).
```

## UI Integration Pattern

### Standard Window Setup

```abl
/* Include business entity classes */
USING business.CustomerEntity FROM PROPATH.
USING business.EntityFactory FROM PROPATH.

/* Include dataset definition */
{business/CustomerDataset.i}

/* Button event handler */
ON CHOOSE OF GetCustomer IN FRAME DEFAULT-FRAME:
    VAR INTEGER iCustomerNumber = INTEGER(CustomerNumber:screen-value).
    VAR EntityFactory objFactory = EntityFactory:GetInstance().
    VAR CustomerEntity objCustomerEntity = objFactory:GetCustomerEntity().
    VAR LOGICAL lCustomerFound.
    
    /* Call entity to fetch data - use OUTPUT DATASET */
    lCustomerFound = objCustomerEntity:GetCustomerByNumber(
        iCustomerNumber, 
        OUTPUT DATASET dsCustomer
    ).
    
    /* Update UI based on results */
    IF lCustomerFound THEN DO:
        FIND FIRST ttCustomer.
        IF AVAILABLE ttCustomer THEN DO:
            CustomerName = ttCustomer.Name.
            DISPLAY CustomerName WITH FRAME {&frame-name}.
        END.
    END.
    ELSE 
        MESSAGE "Customer not found" VIEW-AS ALERT-BOX.
END.
```

## Common Pitfalls and Solutions

### Pitfall 1: Using BY-REFERENCE on OUTPUT DATASET for Read Operations

**Problem**:
```abl
/* WRONG - BY-REFERENCE on OUTPUT causes handle mismatch */
lFound = objEntity:GetCustomerByNumber(iNum, OUTPUT DATASET dsCustomer BY-REFERENCE).
```

**Solution**:
```abl
/* CORRECT - OUTPUT without BY-REFERENCE */
lFound = objEntity:GetCustomerByNumber(iNum, OUTPUT DATASET dsCustomer).
```

**Why**: BusinessEntity fills its internal ProDataSet. OUTPUT copies data back to caller automatically. BY-REFERENCE can create handle conflicts.

### Pitfall 2: Forgetting Change Tracking for Updates

**Problem**:
```abl
/* WRONG - Change tracking not enabled */
FIND FIRST ttCustomer.
ttCustomer.Name = "New Name".
objEntity:UpdateCustomer(INPUT-OUTPUT DATASET dsCustomer BY-REFERENCE).
/* Changes not detected! */
```

**Solution**:
```abl
/* CORRECT - Enable change tracking before modifications */
TEMP-TABLE ttCustomer:TRACKING-CHANGES = TRUE.
FIND FIRST ttCustomer.
ttCustomer.Name = "New Name".
objEntity:UpdateCustomer(INPUT-OUTPUT DATASET dsCustomer BY-REFERENCE).
```

### Pitfall 3: Missing Data-Source to ProDataSource Assignment

**Problem**:
```abl
/* WRONG - Data source defined but not assigned */
DEFINE DATA-SOURCE srcCustomer FOR Customer.

CONSTRUCTOR PUBLIC CustomerEntity():
    SUPER(DATASET dsCustomer:HANDLE).
    /* Missing ProDataSource assignment! */
END CONSTRUCTOR.
```

**Solution**:
```abl
/* CORRECT - Assign data source handles to ProDataSource */
CONSTRUCTOR PUBLIC CustomerEntity():
    SUPER(DATASET dsCustomer:HANDLE).
    
    VAR HANDLE[1] hDataSourceArray = DATA-SOURCE srcCustomer:HANDLE.
    VAR CHARACTER[1] cSkipListArray = [""].
    
    THIS-OBJECT:ProDataSource = hDataSourceArray.
    THIS-OBJECT:SkipList = cSkipListArray.
END CONSTRUCTOR.
```

### Pitfall 4: Direct Database Access from UI

**Problem**:
```abl
/* WRONG - UI directly accessing database */
FIND FIRST Customer WHERE Customer.CustNum = iNum NO-LOCK.
CustomerName = Customer.Name.
```

**Solution**:
```abl
/* CORRECT - Use business entity */
lFound = objCustomerEntity:GetCustomerByNumber(iNum, OUTPUT DATASET dsCustomer).
IF lFound THEN DO:
    FIND FIRST ttCustomer.
    CustomerName = ttCustomer.Name.
END.
```

### Pitfall 5: Not Using Named Buffers

**Problem**:
```abl
/* WRONG - Using table directly without buffer */
FOR EACH Customer WHERE Customer.Country = 'USA':
    /* ... */
END.
```

**Solution**:
```abl
/* CORRECT - Always use named buffers */
DEFINE BUFFER bCustomer FOR Customer.

FOR EACH bCustomer WHERE bCustomer.Country = 'USA':
    /* ... */
END.
```

## Refactoring Legacy Code: Step-by-Step Guide

### Step 1: Identify Data Access Patterns

Analyze legacy code for:
- Direct database FIND/FOR EACH statements
- Database table usage in UI code
- Data validation logic scattered across UI
- Duplicate data access code

### Step 2: Create Dataset Definition

Create `{business/EntityDataset.i}`:

```abl
/* Map database table to temp-table */
DEFINE TEMP-TABLE tt<TableName> BEFORE-TABLE btt<TableName>
    /* Copy all fields from database table */
    FIELD <FieldName> AS <Type> INITIAL "<Default>" LABEL "<Label>"
    /* ... */
    INDEX <IndexName> IS PRIMARY UNIQUE <KeyFields>.

DEFINE DATASET ds<Entity> FOR tt<TableName>.
```

### Step 3: Create Business Entity Class

Create `business/<Entity>Entity.cls`:

```abl
USING Progress.Lang.*.
USING OpenEdge.BusinessLogic.BusinessEntity.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS business.<Entity>Entity INHERITS BusinessEntity USE-WIDGET-POOL:
    
    {business/<Entity>Dataset.i}
    
    DEFINE DATA-SOURCE src<Table> FOR <TableName>.
    
    CONSTRUCTOR PUBLIC <Entity>Entity():
        SUPER(DATASET ds<Entity>:HANDLE).
        
        VAR HANDLE[1] hDataSourceArray = DATA-SOURCE src<Table>:HANDLE.
        VAR CHARACTER[1] cSkipListArray = [""].
        
        THIS-OBJECT:ProDataSource = hDataSourceArray.
        THIS-OBJECT:SkipList = cSkipListArray.
    END CONSTRUCTOR.
    
    /* Add business methods here */
    
END CLASS.
```

### Step 4: Add Entity to Factory

Update `business/EntityFactory.cls`:

```abl
USING business.<Entity>Entity.

CLASS business.EntityFactory:
    /* Add entity instance variable */
    VAR PRIVATE <Entity>Entity obj<Entity>EntityInstance.
    
    /* Add getter method */
    METHOD PUBLIC <Entity>Entity Get<Entity>Entity():
        IF obj<Entity>EntityInstance = ? THEN
            obj<Entity>EntityInstance = NEW <Entity>Entity().
        RETURN obj<Entity>EntityInstance.
    END METHOD.
    
    /* Update cleanup method */
    METHOD PUBLIC VOID ResetAllEntities():
        IF VALID-OBJECT(obj<Entity>EntityInstance) THEN
            DELETE OBJECT obj<Entity>EntityInstance.
        obj<Entity>EntityInstance = ?.
        /* ... other entities ... */
    END METHOD.
END CLASS.
```

### Step 5: Refactor UI Code

Transform direct database access:

**Before**:
```abl
DEFINE BUFFER bCustomer FOR Customer.

FIND FIRST bCustomer WHERE bCustomer.CustNum = iCustNum NO-LOCK NO-ERROR.
IF AVAILABLE bCustomer THEN DO:
    CustomerName = bCustomer.Name.
    DISPLAY CustomerName.
END.
ELSE
    MESSAGE "Customer not found".
```

**After**:
```abl
USING business.CustomerEntity FROM PROPATH.
USING business.EntityFactory FROM PROPATH.

{business/CustomerDataset.i}

VAR EntityFactory objFactory = EntityFactory:GetInstance().
VAR CustomerEntity objEntity = objFactory:GetCustomerEntity().
VAR LOGICAL lFound.

lFound = objEntity:GetCustomerByNumber(iCustNum, OUTPUT DATASET dsCustomer).
IF lFound THEN DO:
    FIND FIRST ttCustomer.
    CustomerName = ttCustomer.Name.
    DISPLAY CustomerName.
END.
ELSE
    MESSAGE "Customer not found".
```

### Step 6: Extract Validation Logic

Move scattered validation to entity:

**Before** (in UI):
```abl
IF CustomerName = "" THEN DO:
    MESSAGE "Name required".
    RETURN.
END.
IF CreditLimit < 0 THEN DO:
    MESSAGE "Invalid credit limit".
    RETURN.
END.
```

**After** (in Entity):
```abl
METHOD PUBLIC LOGICAL ValidateCustomer(INPUT-OUTPUT DATASET dsCustomer,
                                     OUTPUT errorMessage AS CHARACTER):
    VAR LOGICAL isValid = TRUE.
    
    FIND FIRST ttCustomer NO-ERROR.
    IF AVAILABLE ttCustomer THEN DO:
        IF ttCustomer.Name = "" THEN DO:
            isValid = FALSE.
            errorMessage = "Name required".
            RETURN isValid.
        END.
        IF ttCustomer.CreditLimit < 0 THEN DO:
            isValid = FALSE.
            errorMessage = "Invalid credit limit".
            RETURN isValid.
        END.
    END.
    
    RETURN isValid.
END METHOD.
```

**UI Usage**:
```abl
isValid = objEntity:ValidateCustomer(
    INPUT-OUTPUT DATASET dsCustomer BY-REFERENCE,
    OUTPUT cErrorMessage
).
IF NOT isValid THEN
    MESSAGE cErrorMessage VIEW-AS ALERT-BOX.
```

### Step 7: Test Incrementally

1. Create entity with basic read operation
2. Test read in one UI component
3. Add create/update/delete operations
4. Refactor one UI component at a time
5. Add validation and business rules
6. Verify all functionality works

## Benefits of This Architecture

### Maintainability
- Centralized data access logic
- Changes in one place affect all consumers
- Clear separation of concerns

### Reusability
- Business entities shared across multiple UI components
- Validation logic not duplicated
- Factory pattern enables easy testing

### Testability
- Business logic isolated from UI
- Can test entity methods independently
- Mock data sources for unit testing

### Consistency
- All data access follows same pattern
- Standard error handling
- Uniform validation approach

### Scalability
- Easy to add new entities
- Multi-table relationships well-supported
- Can extend with additional business rules

## References

- OpenEdge Documentation: Business Entity Class
- ABL Reference: Dataset and Temp-Table Definitions
- Design Patterns: Factory and Singleton patterns
- Project Examples:
  - `src/business/CustomerEntity.cls`
  - `src/business/EntityFactory.cls`
  - `src/CustomerWin.w`
