/*------------------------------------------------------------------------
  File        : ItemDataset.i
  Purpose     : Dataset definition for Item entity
  Syntax      : 
  Description : 
  Author(s)   : 
  Created     : Tue Nov 03 11:00:00 CET 2026
  Notes       : 
----------------------------------------------------------------------*/

/* Define temp-table for Item */
DEFINE TEMP-TABLE ttItem BEFORE-TABLE bttItem
    FIELD ItemNum AS INTEGER INITIAL "0" LABEL "Item Num"
    FIELD ItemName AS CHARACTER LABEL "Item Name"
    FIELD CatPage AS INTEGER INITIAL "0" LABEL "Cat Page"
    FIELD Price AS DECIMAL INITIAL "0" LABEL "Price"
    FIELD CatDescription AS CHARACTER LABEL "Cat-Description"
    FIELD OnHand AS INTEGER INITIAL "0" LABEL "On Hand"
    FIELD Allocated AS INTEGER INITIAL "0" LABEL "Allocated"
    FIELD ReOrder AS INTEGER INITIAL "0" LABEL "Re Order"
    FIELD OnOrder AS INTEGER INITIAL "0" LABEL "On Order"
    FIELD Category1 AS CHARACTER LABEL "Category1"
    FIELD Category2 AS CHARACTER LABEL "Category2"
    FIELD Special AS CHARACTER LABEL "Special"
    FIELD Weight AS DECIMAL INITIAL "0" LABEL "Weight"
    FIELD Minqty AS INTEGER INITIAL "0" LABEL "Min Qty"
    INDEX ItemNum IS PRIMARY UNIQUE ItemNum ASCENDING.

/* Define dataset for Item */
DEFINE DATASET dsItem FOR ttItem.
