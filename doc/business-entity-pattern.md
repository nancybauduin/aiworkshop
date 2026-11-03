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

### Create / Update / Delete Operations

```abl
METHOD PUBLIC VOID CreateCustomer(INPUT-OUTPUT DATASET dsCustomer):
    THIS-OBJECT:CreateData(DATASET dsCustomer BY-REFERENCE).
END METHOD.

METHOD PUBLIC VOID UpdateCustomer(INPUT-OUTPUT DATASET dsCustomer):
    THIS-OBJECT:UpdateData(DATASET dsCustomer BY-REFERENCE).
END METHOD.

METHOD PUBLIC VOID DeleteCustomer(INPUT-OUTPUT DATASET dsCustomer):
    THIS-OBJECT:DeleteData(DATASET dsCustomer BY-REFERENCE).
END METHOD.
```

**Update usage from UI with validation**:
```abl
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
        objCustomerEntity:UpdateCustomer(INPUT-OUTPUT DATASET dsCustomer BY-REFERENCE).
    ELSE
        MESSAGE cErrorMessage VIEW-AS ALERT-BOX.
END.
```

**Critical Steps for updates**:
1. Fetch current data using OUTPUT DATASET
2. Enable TRACKING-CHANGES on temp-table
3. Modify temp-table fields
4. Validate changes
5. Call UpdateData() with BY-REFERENCE

## Validation Pattern

```abl
METHOD PUBLIC LOGICAL ValidateCustomer(INPUT-OUTPUT DATASET dsCustomer,
                                     OUTPUT errorMessage AS CHARACTER):
    VAR LOGICAL isValid = TRUE.
    
    FIND FIRST ttCustomer NO-ERROR.
    IF AVAILABLE ttCustomer THEN DO:
        IF ttCustomer.Name = "" THEN DO:
            isValid = FALSE.
            errorMessage = "Customer name cannot be empty".
        END.
    END.
    
    RETURN isValid.
END METHOD.
```

## UI Integration Pattern

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
    
    lCustomerFound = objCustomerEntity:GetCustomerByNumber(
        iCustomerNumber, 
        OUTPUT DATASET dsCustomer
    ).
    
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

1. **BY-REFERENCE on OUTPUT DATASET for reads** - Use plain `OUTPUT DATASET`; the parent fills its internal ProDataSet and OUTPUT copies back automatically.
2. **Forgetting TRACKING-CHANGES for updates** - Enable `TEMP-TABLE ttX:TRACKING-CHANGES = TRUE` before modifying data, or changes won't be detected.
3. **Missing ProDataSource assignment** - Data-source handles must be assigned to `THIS-OBJECT:ProDataSource` (with matching SkipList) in the constructor.
4. **Direct database access from UI** - Always go through the business entity instead of FIND/FOR EACH on database tables.
5. **Not using named buffers** - Always define `DEFINE BUFFER bX FOR X.` for database access.

## Benefits

- **Maintainability**: Centralized data access logic
- **Reusability**: Entities shared across UI components; factory enables easy testing
- **Testability**: Business logic isolated from UI
- **Consistency**: Uniform pattern, error handling, and validation
- **Scalability**: Easy to add new entities and multi-table relationships

## References

- OpenEdge Documentation: Business Entity Class
- ABL Reference: Dataset and Temp-Table Definitions
- Project Examples:
  - `src/business/CustomerEntity.cls`
  - `src/business/EntityFactory.cls`
  - `src/CustomerWin.w`
