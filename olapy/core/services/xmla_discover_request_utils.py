discover_schema_rowsets_response_rows = [
    {
        "SchemaName": "DBSCHEMA_CATALOGS",
        "SchemaGuid": "C8B52211-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": ["CATALOG_NAME"],
            "restriction_types": ["string"],
        },
        "RestrictionsMask": "1",
    },
    {
        "SchemaName": "DISCOVER_LITERALS",
        "SchemaGuid": "C3EF5ECB-0A07-4665-A140-B075722DBDC2",
        "restrictions": {
            "restriction_names": ["LiteralName"],
            "restriction_types": ["string"],
        },
        "RestrictionsMask": "1",
    },
    {
        "SchemaName": "DISCOVER_PROPERTIES",
        "SchemaGuid": "4B40ADFB-8B09-4758-97BB-636E8AE97BCF",
        "restrictions": {
            "restriction_names": ["PropertyName"],
            "restriction_types": ["string"],
        },
        "RestrictionsMask": "1",
    },
    {
        "SchemaName": "DISCOVER_SCHEMA_ROWSETS",
        "SchemaGuid": "EEA0302B-7922-4992-8991-0E605D0E5593",
        "restrictions": {
            "restriction_names": ["SchemaName"],
            "restriction_types": ["string"],
        },
        "RestrictionsMask": "1",
    },
    {
        "SchemaName": "DMSCHEMA_MINING_MODELS",
        "SchemaGuid": "3ADD8A77-D8B9-11D2-8D2A-00E029154FDE",
        "restrictions": {
            "restriction_names": [
                "MODEL_CATALOG",
                "MODEL_SCHEMA",
                "MODEL_NAME",
                "MODEL_TYPE",
                "SERVICE_NAME",
                "SERVICE_TYPE_ID",
                "MINING_STRUCTURE",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedInt",
                "string",
            ],
        },
        "RestrictionsMask": "127",
    },
    {
        "SchemaName": "MDSCHEMA_ACTIONS",
        "SchemaGuid": "A07CCD08-8148-11D0-87BB-00C04FC33942",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "ACTION_NAME",
                "ACTION_TYPE",
                "COORDINATE",
                "COORDINATE_TYPE",
                "INVOCATION",
                "CUBE_SOURCE",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "int",
                "string",
                "int",
                "int",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "511",
    },
    {
        "SchemaName": "MDSCHEMA_CUBES",
        "SchemaGuid": "C8B522D8-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "CUBE_SOURCE",
                "BASE_CUBE_NAME",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "unsignedShort",
                "string",
            ],
        },
        "RestrictionsMask": "31",
    },
    {
        "SchemaName": "MDSCHEMA_DIMENSIONS",
        "SchemaGuid": "C8B522D9-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "DIMENSION_NAME",
                "DIMENSION_UNIQUE_NAME",
                "CUBE_SOURCE",
                "DIMENSION_VISIBILITY",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedShort",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "127",
    },
    {
        "SchemaName": "MDSCHEMA_FUNCTIONS",
        "SchemaGuid": "A07CCD07-8148-11D0-87BB-00C04FC33942",
        "restrictions": {
            "restriction_names": [
                "LIBRARY_NAME",
                "INTERFACE_NAME",
                "FUNCTION_NAME",
                "ORIGIN",
            ],
            "restriction_types": ["string", "string", "string", "int"],
        },
        "RestrictionsMask": "15",
    },
    {
        "SchemaName": "MDSCHEMA_HIERARCHIES",
        "SchemaGuid": "C8B522DA-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "DIMENSION_UNIQUE_NAME",
                "HIERARCHY_NAME",
                "HIERARCHY_UNIQUE_NAME",
                "HIERARCHY_ORIGIN",
                "CUBE_SOURCE",
                "HIERARCHY_VISIBILITY",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedShort",
                "unsignedShort",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "511",
    },
    {
        "SchemaName": "MDSCHEMA_INPUT_DATASOURCES",
        "SchemaGuid": "A07CCD32-8148-11D0-87BB-00C04FC33942",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "DATASOURCE_NAME",
                "DATASOURCE_TYPE",
            ],
            "restriction_types": ["string", "string", "string", "string"],
        },
        "RestrictionsMask": "15",
    },
    {
        "SchemaName": "MDSCHEMA_KPIS",
        "SchemaGuid": "2AE44109-ED3D-4842-B16F-B694D1CB0E3F",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "KPI_NAME",
                "CUBE_SOURCE",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "31",
    },
    {
        "SchemaName": "MDSCHEMA_LEVELS",
        "SchemaGuid": "C8B522DB-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "DIMENSION_UNIQUE_NAME",
                "HIERARCHY_UNIQUE_NAME",
                "LEVEL_NAME",
                "LEVEL_UNIQUE_NAME",
                "LEVEL_ORIGIN",
                "CUBE_SOURCE",
                "LEVEL_VISIBILITY",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedShort",
                "unsignedShort",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "1023",
    },
    {
        "SchemaName": "MDSCHEMA_MEASUREGROUPS",
        "SchemaGuid": "E1625EBF-FA96-42FD-BEA6-DB90ADAFD96B",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "MEASUREGROUP_NAME",
            ],
            "restriction_types": ["string", "string", "string", "string"],
        },
        "RestrictionsMask": "15",
    },
    {
        "SchemaName": "MDSCHEMA_MEASUREGROUP_DIMENSIONS",
        "SchemaGuid": "A07CCD33-8148-11D0-87BB-00C04FC33942",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "MEASUREGROUP_NAME",
                "DIMENSION_UNIQUE_NAME",
                "DIMENSION_VISIBILITY",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "63",
    },
    {
        "SchemaName": "MDSCHEMA_MEASURES",
        "SchemaGuid": "C8B522DC-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "MEASURE_NAME",
                "MEASURE_UNIQUE_NAME",
                "MEASUREGROUP_NAME",
                "CUBE_SOURCE",
                "MEASURE_VISIBILITY",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedShort",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "255",
    },
    {
        "SchemaName": "MDSCHEMA_MEMBERS",
        "SchemaGuid": "C8B522DE-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "DIMENSION_UNIQUE_NAME",
                "HIERARCHY_UNIQUE_NAME",
                "LEVEL_UNIQUE_NAME",
                "LEVEL_NUMBER",
                "MEMBER_NAME",
                "MEMBER_UNIQUE_NAME",
                "MEMBER_CAPTION",
                "MEMBER_TYPE",
                "TREE_OP",
                "CUBE_SOURCE",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedInt",
                "string",
                "string",
                "string",
                "int",
                "int",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "8191",
    },
    {
        "SchemaName": "MDSCHEMA_PROPERTIES",
        "SchemaGuid": "C8B522DD-5CF3-11CE-ADE5-00AA0044773D",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "DIMENSION_UNIQUE_NAME",
                "HIERARCHY_UNIQUE_NAME",
                "LEVEL_UNIQUE_NAME",
                "MEMBER_UNIQUE_NAME",
                "PROPERTY_NAME",
                "PROPERTY_TYPE",
                "PROPERTY_CONTENT_TYPE",
                "PROPERTY_ORIGIN",
                "CUBE_SOURCE",
                "PROPERTY_VISIBILITY",
            ],
            "restriction_types": [
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "string",
                "unsignedShort",
                "unsignedShort",
                "unsignedShort",
            ],
        },
        "RestrictionsMask": "8191",
    },
    {
        "SchemaName": "MDSCHEMA_SETS",
        "SchemaGuid": "A07CCD0B-8148-11D0-87BB-00C04FC33942",
        "restrictions": {
            "restriction_names": [
                "CATALOG_NAME",
                "SCHEMA_NAME",
                "CUBE_NAME",
                "SET_NAME",
                "SCOPE",
            ],
            "restriction_types":
                ["string", "string", "string", "string", "int"],
        },
        "RestrictionsMask": "31",
    },
]

discover_literals_response_rows = [
    {
        "LiteralName": "DBLITERAL_CATALOG_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "24",
        "LiteralNameEnumValue": "2",
    },
    {
        "LiteralName": "DBLITERAL_CATALOG_SEPARATOR",
        "LiteralValue": ".",
        "LiteralMaxLength": "0",
        "LiteralNameEnumValue": "3",
    },
    {
        "LiteralName": "DBLITERAL_COLUMN_ALIAS",
        "LiteralInvalidChars": "'&quot;[]",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "5",
    },
    {
        "LiteralName": "DBLITERAL_COLUMN_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "6",
    },
    {
        "LiteralName": "DBLITERAL_CORRELATION_NAME",
        "LiteralInvalidChars": "'&quot;[]",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "7",
    },
    {
        "LiteralName": "DBLITERAL_CUBE_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "21",
    },
    {
        "LiteralName": "DBLITERAL_DIMENSION_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "22",
    },
    {
        "LiteralName": "DBLITERAL_LEVEL_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "24",
    },
    {
        "LiteralName": "DBLITERAL_MEMBER_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "25",
    },
    {
        "LiteralName": "DBLITERAL_PROCEDURE_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "14",
    },
    {
        "LiteralName": "DBLITERAL_PROPERTY_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "26",
    },
    {
        "LiteralName": "DBLITERAL_QUOTE_PREFIX",
        "LiteralValue": "[",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "15",
    },
    {
        "LiteralName": "DBLITERAL_QUOTE_SUFFIX",
        "LiteralValue": "]",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "28",
    },
    {
        "LiteralName": "DBLITERAL_TABLE_NAME",
        "LiteralInvalidChars": ".",
        "LiteralInvalidStartingChars": "0123456789",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "17",
    },
    {
        "LiteralName": "DBLITERAL_TEXT_COMMAND",
        "LiteralMaxLength": "-1",
        "LiteralNameEnumValue": "18",
    },
    {
        "LiteralName": "DBLITERAL_USER_NAME",
        "LiteralMaxLength": "0",
        "LiteralNameEnumValue": "19",
    },
]
