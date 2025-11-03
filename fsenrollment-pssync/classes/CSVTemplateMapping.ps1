#Requires -Version 7.0

<#
.SYNOPSIS
    CSV template mapping classes for defining how to parse different CSV formats.

.DESCRIPTION
    Defines classes that configure how to map CSV columns to PowerSchool entities.
    This allows support for multiple CSV formats from different sources.
#>

# Defines a mapping from CSV column to PowerSchool entity property
class ColumnMapping {
    [string]$CSVColumn
    [string]$EntityProperty
    [string]$DataType
    [scriptblock]$Transform

    ColumnMapping() {}
    
    ColumnMapping([string]$csvColumn, [string]$entityProperty) {
        $this.CSVColumn = $csvColumn
        $this.EntityProperty = $entityProperty
        $this.DataType = 'string'
    }
    
    ColumnMapping([string]$csvColumn, [string]$entityProperty, [string]$dataType) {
        $this.CSVColumn = $csvColumn
        $this.EntityProperty = $entityProperty
        $this.DataType = $dataType
    }
}

# Defines how to parse a specific CSV template
class CSVTemplateMapping {
    [string]$TemplateName
    [string]$Description
    [string]$EntityType
    [System.Collections.Generic.List[ColumnMapping]]$ColumnMappings
    [hashtable]$CustomParsers

    CSVTemplateMapping() {
        $this.ColumnMappings = [System.Collections.Generic.List[ColumnMapping]]::new()
        $this.CustomParsers = @{}
    }
    
    CSVTemplateMapping([string]$templateName, [string]$entityType) {
        $this.TemplateName = $templateName
        $this.EntityType = $entityType
        $this.ColumnMappings = [System.Collections.Generic.List[ColumnMapping]]::new()
        $this.CustomParsers = @{}
    }
    
    [void] AddMapping([string]$csvColumn, [string]$entityProperty) {
        $this.ColumnMappings.Add([ColumnMapping]::new($csvColumn, $entityProperty))
    }
    
    [void] AddMapping([string]$csvColumn, [string]$entityProperty, [string]$dataType) {
        $this.ColumnMappings.Add([ColumnMapping]::new($csvColumn, $entityProperty, $dataType))
    }
}
