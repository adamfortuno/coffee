<#
	Copyright (C) 2018  Adam Fortuno

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU Affero General Public License as published
	by the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU Affero General Public License for more details.

	You should have received a copy of the GNU Affero General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>
Set-StrictMode -Version 5.0

## Global variables and enumerations
$script:self_location = $script:MyInvocation.MyCommand.Path
$script:database_connection = $Null
$script:random_number_generator = New-Object 'System.Random' -ArgumentList $(Get-Random)

## Initializes and loads the Configuration library used to parse the 
## Application configuration file.
[Configuration.ConfigurationManager].GetField("s_initState", "NonPublic, Static").SetValue($null, 0)
Add-Type -AssemblyName System.Configuration
Add-Type -AssemblyName System.Windows.Forms

## Verify that the script knows its location
if ( [string]::IsNullOrEmpty($script:self_location) ) {
    throw "Unable to determine location of application script."
}

## The configuration file hosts all default values. Loading that file here.
$script:configuration_file_location = "${script:self_location}.config"

## If the configuration file exists, load it; otherwise, throw.
if ( $(Test-Path -Path $script:configuration_file_location) ) {
    [System.AppDomain]::CurrentDomain.SetData("APP_CONFIG_FILE", $script:configuration_file_location)
} else {
    throw "Unable to locate configuration file. This script's configuration file should reside in the same directory as the script."
}
    
$script:database_connection_string = `
    [System.Configuration.ConfigurationManager]::AppSettings["coffee.db_connection_string"]

enum OrderStatusType { Initiated = 1; Entered = 2; Served = 3 }
enum WorkloadType { Read = 1; Write = 2; Update = 3 }

function Get-CoffeeDBConnectionString {
    <#
        .Synopsis
        Get Coffee Database Connection String

        .Description
        Returns the connection string to the Coffee database.

        .Example
        Get-CoffeeDBConnectionString

        Returns the connection string to the Coffee database.

    #>
    return $script:database_connection_string
}

function Set-CoffeeDBConnectionString {
    <#
        .Synopsis
        Assigns the connection string to the Coffee database
        
        .Description
        Assigns the connection string for the Coffee database.

        .Parameter DBConnectionString
        The connection string for a given Coffee database.

        .Example
        Set-CoffeeDBConnectionString -DBConnectionString "Server='(local)';Database='coffee_ae';Column Encryption Setting=enabled;Integrated Security=True;"
    #>
    [CmdletBinding()]
    Param(
        [string]$DBConnectionString
    )
    
    $script:database_connection_string = $DBConnectionString
}

function Get-CoffeeRandomNumber {
    <#
        .Synopsis
        Generates a Random Number
        
        .Description
        This function generates a random number with-in a specified range.
        In contrast to `Get-CoffeeRandomNumber`, this is a light weight psuedorandom
        number generator that uses minimal resources.

        .Example
        Get-CoffeeRandomNumber

        Generates a random number between 1 and 12 (the defaults).

        .Example
        Get-CoffeeRandomNumber -Minimum 2

        Generates a random number between 5 and 12 (12 is the default). 

        .Example
        Get-CoffeeRandomNumber -Minimum 5 -Maximum 10

        Generates a random number between 5 and 10.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,Position=1)][int32]$Minimum
      , [Parameter(Mandatory=$false,Position=2)][int32]$Maximum
    )

    if ( $script:random_number_generator -eq $null ) {
        
        Write-verbose 'Generating random number generator...'
        
        $script:random_number_generator = `
            New-Object 'System.Random' -ArgumentList $(Get-Random)
    }
    
    $generated_number = $script:random_number_generator.Next($Minimum, $Maximum)

    Write-Verbose `
        -Message $("Minimum was {0}, maximum was {1}, and generated was {2}." -f $Minimum, $Maximum, $generated_number)

    return $generated_number
}

function Initialize-CoffeeDBConnection {
    <#
        .Synopsis
        Create a New Coffee Database Connection
        
        .Description
        This function returns a new database connection to the Coffee
        database. The connection string use is that found in the script's
        configuration file.

        .Example
        Initialize-CoffeeDBConnection
    #>
    [CmdletBinding()]
    Param()

    Write-Verbose 'Initialize-CoffeeDBConnection: Creating connection object...'
    Write-Verbose "Value (database_connection_string): ${database_connection_string}"

    $script:database_connection = New-Object 'System.Data.SqlClient.SqlConnection'
    $script:database_connection.ConnectionString = $script:database_connection_string
}

function Disconnect-CoffeeDBConnection {
    <#
        .Synopsis
        Clean-up an Existing Database Connection to the Coffee Database
        
        .Description
        Terminates a Coffee database connection and tags it for
        garbage collection.

        .Example
        Disconnect-CoffeeDBConnection
    #>
    [CmdletBinding()]
    Param()

    if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Open ) {
        $script:database_connection.Close()
    }

    $script:database_connection.Dispose()
}

function Start-CoffeeDBTransaction {
    <#
        .Synopsis
        Start a Database Transaction
        
        .Description
        Creates and returns a database transaction for use in
        a given batch.

        .Example
        $db_transaction = Start-CoffeeDBTransaction
        
    #>
    [CmdletBinding()]
    Param()

    if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
        throw "Please open the transaction before proceeding."
    }
    
    return $script:database_connection.BeginTransaction()
}

function Get-RandomString {
    <#
        .Synopsis
        Generate a Random String
        
        .Description
        Returns a random string of the spcified length. The
        string includes numbers, mixed case characters, and
        punctuation.

        .Parameter Length
        The length of the random string fabricated.

        .Example
        $random = Get-RandomString -Length 10

        Creates a random string 10-characters in length and
        assigns it to the variable $random.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)][int]$Length
    )
    Add-Type -AssemblyName System.Web

    return [System.Web.Security.Membership]::GeneratePassword($Length, 0)
}

function Add-CoffeeOrder {
    <#
        .Synopsis
        Create a New Order
        
        .Description
        Creates an order. Data for the order includes both order
        and order detail data.

        .Parameter OrderStatusType
        The order's status.

        .Parameter CreditCardAccountNumber
        The account number associated with the consumer's credit card.

        .Parameter CreditCardCVV
        The CVV number associated with the consumer's credit card.

        .Parameter CustomerID
        The customer's identifier.

        .Example
        Add-CoffeeOrder -CreditCardAccountNumber 1234567890123456789 `
            -CreditCardCVV 123 `
            -CustomerID 3
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,Position=1)][OrderStatusType]$OrderStatusType = [OrderStatusType]::Entered
      , [Parameter(Mandatory=$true,Position=2)][string]$CreditCardAccountNumber
      , [Parameter(Mandatory=$true,Position=3)][string]$CreditCardCVV
      , [Parameter(Mandatory=$true,Position=4)][string]$CustomerID
      , [Parameter(Mandatory=$false,Position=5)][System.Data.SqlClient.SqlTransaction]$DBTransaction
    )

    if ( $script:database_connection -eq $Null ) {
        throw "Please call 'Initialize-DBConnection' to initialize the database connection."
    }

    $order_id = -1
    $sql_order_insert = @"
INSERT INTO dbo.[order] ([status], account_number, cvv_code, id_customer)
VALUES (@order_status, @order_account_number, @order_cvv_code, @order_id_customer);
SELECT SCOPE_IDENTITY();
"@

    try {
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }
       
        $database_order_create = New-Object 'System.Data.SqlClient.SqlCommand' `
            -ArgumentList $sql_order_insert, $script:database_connection, $DBTransaction
        
        ## Create a new record for the order
        $database_order_create.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@order_status",[Data.SQLDBType]::int))) | Out-Null
        $database_order_create.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@order_account_number",[Data.SQLDBType]::VarChar, 19))) | Out-Null
        $database_order_create.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@order_cvv_code",[Data.SQLDBType]::VarChar, 3))) | Out-Null
        $database_order_create.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@order_id_customer",[Data.SQLDBType]::int))) | Out-Null
        $database_order_create.Parameters[0].Value = $OrderStatusType.value__
        $database_order_create.Parameters[1].Value = $CreditCardAccountNumber
        $database_order_create.Parameters[2].Value = $CreditCardCVV
        $database_order_create.Parameters[3].Value = $CustomerID
        
        $order_id = [convert]::ToInt32($database_order_create.ExecuteScalar().ToString())
    } catch {
        $exception_message = "Statement: {0}; Status: {1}; CustomerID: {2}" -f `
            $sql_order_insert `
          , $OrderStatusType.value__ `
          , $CustomerID

        $_.exception.data['statement_detail'] = $exception_message
        
        throw $_.exception
    } finally {
        if ( $DBTransaction -eq $Null) {
            $script:database_connection.Close()
        }
    }
    
    return $order_id
}

function Add-CoffeeOrderDetail {
    <#
        .Synopsis
        Create an Order Details
        
        .Description
        Creates a detail records for a given order. Details
        records include what was purchased and the quantity. 

        .Parameter OrderID
        The order_id value for the order associated with this
        record (the order who's detail is being added)

        .Parameter ItemID
        The item_id for the item being purchased.

        .Parameter Quantity
        The number of items being purchased.

        .Example
        Add-CoffeeOrderDetail -OrderID 10 -ItemID 2 -Quantity 12
    #>
    Param(
        [Parameter(Mandatory=$true,Position=1)][int]$OrderID
      , [Parameter(Mandatory=$true,Position=2)][int]$ItemID
      , [Parameter(Mandatory=$true,Position=3)][int]$Quantity
      , [Parameter(Mandatory=$false,Position=4)]
        [System.Data.SqlClient.SqlTransaction]
        $DBTransaction
    )

    $order_detail_id = -1

    $sql_order_detail_insert = @"
INSERT INTO dbo.order_detail ([id_order], [id_sustenance], [quantity])
VALUES (@id_order, @id_sustenance, @quantity);
SELECT SCOPE_IDENTITY()
"@

    try {
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }
    
        $db_order_detail_create = New-Object 'System.Data.SqlClient.SqlCommand' `
            -ArgumentList $sql_order_detail_insert, $script:database_connection, $DBTransaction

        $db_order_detail_create.CommandText = $sql_order_detail_insert
        $db_order_detail_create.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@id_order", [Data.SQLDBType]::int))) | Out-Null
        $db_order_detail_create.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@id_sustenance", [Data.SQLDBType]::Int))) | Out-Null
        $db_order_detail_create.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@quantity", [Data.SQLDBType]::Int))) | Out-Null
        $db_order_detail_create.Parameters[0].Value = $OrderID
        $db_order_detail_create.Parameters[1].Value = $ItemID
        $db_order_detail_create.Parameters[2].Value = $Quantity
        
        $order_detail_id = [convert]::ToInt32($db_order_detail_create.ExecuteScalar().ToString())
    } catch {
        $exception_message = "Statement: {0}; OrderID: {1}; ItemID: {2}; Quantity {3}" -f `
            $sql_order_detail_insert `
          , $OrderID `
          , $ItemID `
          , $Quantity

        $_.exception.data['statement_detail'] = $exception_message

        throw $_.Exception
    } finally {
        if ( $DBTransaction -eq $Null) {
            $script:database_connection.Close()
        }
    }

    return $order_detail_id
}

function Update-CoffeeOrder {
    <#
        .Synopsis
        Update an Existing Order
        
        .Description
        Updates the status of an existing order.

        .Parameter OrderID
        The subject order's order identifier (order_id).

        .Parameter OrderStatusType
        The order's new status.

        .Example
        Update-CoffeeOrder -OrderID 14
    #>
    Param (
        [int]$OrderID
      , [OrderStatusType]$OrderStatusType = [OrderStatusType]::Served
    )

    $sql_order_status_update = @"
UPDATE dbo.[order]
SET status = @order_status
WHERE id_order = @id_order;
"@

    try {
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }

        $db_order_status_update = New-Object 'System.Data.SqlClient.SqlCommand'
        $db_order_status_update.Connection = $script:database_connection

        $db_order_status_update.CommandText = $sql_order_status_update
        $db_order_status_update.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@order_status",[Data.SQLDBType]::char, 1))) | Out-Null
        $db_order_status_update.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@id_order",[Data.SQLDBType]::Int))) | Out-Null
        $db_order_status_update.Parameters[0].Value = $OrderStatusType.Value__
        $db_order_status_update.Parameters[1].Value = $OrderID

        $db_order_status_update.ExecuteNonQuery() | Out-Null
    } catch {
        $exception_message = "Statement: {0}; OrderStatus: {1}; OrderID: {2}" -f `
            $sql_order_status_update `
          , $OrderStatusType.Value__ `
          , $OrderID

        $_.exception.data['statement_detail'] = $exception_message

        throw $_.Exception
    } finally {
        $script:database_connection.Close()
    }
}

function Get-CoffeeOrder {
    <#
        .Synopsis
        Get a Specified Order
        
        .Description
        Gets a specified order and order's detail information.

        .Parameter OrderID
        The identifier for the order being retrieved.

        .Example
        Get-CoffeeOrder -OrderID 3
    #>
    Param (
        [int]$OrderID
    )

    $sql_get_order_data = "EXECUTE [dbo].[coffee_get_order] @id_order = @id_order;"
    $db_order_data = New-Object 'System.Data.DataSet'

    try {
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }

        $db_get_order_data = New-Object 'System.Data.SqlClient.SqlCommand'
        $db_get_order_data.Connection = $script:database_connection

        $db_get_order_data.CommandText = $sql_get_order_data
        $db_get_order_data.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@id_order",[Data.SQLDBType]::Int))) | Out-Null
        $db_get_order_data.Parameters[0].Value = $OrderID
    
        $db_adapt_order_data = New-Object 'System.Data.sqlclient.sqlDataAdapter' `
            -ArgumentList $db_get_order_data
        
        $db_adapt_order_data.Fill($db_order_data, "orders") | Out-Null
    } catch {
        throw $_.Exception
    } finally {
        $script:database_connection.Close()
    }

    return $db_order_data
}

function Get-CoffeeOrderIDRandom {
    $order_id = -1
    $sql_get_order_id_random = "EXECUTE [dbo].[coffee_get_order_random] @order_status = @order_status;"

    try {
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }

        $db_get_order_id_random = New-Object 'System.Data.SqlClient.SqlCommand'
        $db_get_order_id_random.Connection = $script:database_connection
        
        $db_get_order_id_random.CommandText = $sql_get_order_id_random
        $db_get_order_id_random.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@order_status",[Data.SQLDBType]::Int))) | Out-Null
        $db_get_order_id_random.Parameters[0].Value = [OrderStatusType]::Entered.Value__
        
        $order_id = [int]$db_get_order_id_random.ExecuteScalar()
    } finally {
        $database_connection.Close()
    }

    return $order_id
}

function Get-CoffeeCustomerIDMax {

    $customer_id = -1
    $sql_get_customer_id_newest = "SELECT MAX(id_customer) FROM dbo.Customer WITH (NOLOCK);"

    try {
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }

        $db_get_customer_id_newest = New-Object 'System.Data.SqlClient.SqlCommand'
        $db_get_customer_id_newest.Connection = $script:database_connection

        $db_get_customer_id_newest.CommandText = $sql_get_customer_id_newest

        $customer_id = [int]$db_get_customer_id_newest.ExecuteScalar()
    } finally {
        $database_connection.Close()
    }

    return $customer_id
}

function Get-CoffeeSustenanceIDMax {

    $sustenance_id = -1
    $sql_get_sustenance_id_newest = "SELECT MAX(id_sustenance) FROM dbo.sustenance WITH (NOLOCK);"

    try {
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }

        $db_get_sustenance_id_newest = New-Object 'System.Data.SqlClient.SqlCommand'
        $db_get_sustenance_id_newest.Connection = $script:database_connection

        $db_get_sustenance_id_newest.CommandText = $sql_get_sustenance_id_newest

        $sustenance_id = [int]$db_get_sustenance_id_newest.ExecuteScalar()
    } finally {
        $database_connection.Close()
    }

    return $sustenance_id
}

function Invoke-CoffeeWorkloadWrite {
    <#
        .Synopsis
        Invoke Write Workload
        
        .Description
        Submits a write transaction to Coffee.

        .Parameter WorkloadType
        The type of workload being fabricated.

        .Parameter TerminalCount
        The number of virtual terminals issuing transacitons. Said
        differently the number threads generating load.

        .Parameter TestDurationInSeconds
        The test's duration expressed in seconds.

        .Example
        Invoke-CoffeeWorkloadWrite
    #>
    [CmdletBinding()]
    Param()

    try {
        Initialize-CoffeeDBConnection

        ## Workflow-1: Create Order
        $customer_id_max = Get-CoffeeCustomerIDMax
        $sustenance_id_max = Get-CoffeeSustenanceIDMax
        $order_detail_items = Get-CoffeeRandomNumber -Minimum 1 -Maximum 8
        $order_credit_card_number = $(Get-CoffeeRandomNumber -Minimum 100000000 -Maximum 999999999).ToString() 
        $order_credit_card_number += $(Get-CoffeeRandomNumber -Minimum 100000000 -Maximum 999999999).ToString()

        ## Since I'm inserting an order and related order items as a
        ## unit, I'm wrapping those inserts in a transaction

        ## You need to open the database connection before creating
        ## a transaction
        if ( $script:database_connection.State -eq [System.Data.ConnectionState]::Closed ) {
            $script:database_connection.Open()
        }
        
        ## Create your transaction
        $db_transaction = Start-CoffeeDBTransaction
        
        $order_id = Add-CoffeeOrder -CreditCardAccountNumber $order_credit_card_number `
            -CreditCardCVV $(Get-CoffeeRandomNumber -Maximum 999 -Minimum 100) `
            -CustomerID $(Get-CoffeeRandomNumber -Minimum 1 -Maximum $customer_id_max) `
            -DBTransaction $db_transaction

        Write-Verbose "Order ${order_id} was created..."

        if ( $order_detail_items -gt 0 ) {
            Write-Verbose "Adding ${order_detail_items}-items to this order..."

            for($i = 1; $i -le $order_detail_items; $i++) {
                Add-CoffeeOrderDetail -OrderID $order_id `
                    -ItemID $(Get-CoffeeRandomNumber -Minimum 1 -Maximum $sustenance_id_max) `
                    -Quantity $(Get-CoffeeRandomNumber -Minimum 1 -Maximum 12) `
                    -DBTransaction $db_transaction `
                | Out-Null
                
                Write-Verbose "...item ${i} was added"
            }
        }
        
        $db_transaction.Commit()
    } catch {
        ## Something bad happened. Roll the change back and 
        ## rethrow the exception
        #$db_transaction.Rollback()
        throw $_.Exception
    } finally {
        $db_transaction.Dispose()
        Disconnect-CoffeeDBConnection
    }
}


function Invoke-CoffeeWorkloadUpdate {
    <#
        .Synopsis
        TBA
        
        .Description
        TBA

        .Parameter WorkloadType
        The type of workload being fabricated.

        .Parameter TerminalCount
        The number of virtual terminals issuing transacitons. Said
        differently the number threads generating load.

        .Parameter TestDurationInSeconds
        The test's duration expressed in seconds.

        .Example
        Invoke-CoffeeWorkloadUpdate
    #>
    [CmdletBinding()]
    Param()

    try {
        Initialize-CoffeeDBConnection
        
        ## Workflow-2: Update Order
        Update-CoffeeOrder -OrderID $(Get-CoffeeOrderIDRandom)

    } finally {
        Disconnect-CoffeeDBConnection
    }
}

function Invoke-CoffeeWorkloadRead {
    <#
        .Synopsis
        TBA
        
        .Description
        TBA

        .Parameter WorkloadType
        The type of workload being fabricated.

        .Parameter TerminalCount
        The number of virtual terminals issuing transacitons. Said
        differently the number threads generating load.

        .Parameter TestDurationInSeconds
        The test's duration expressed in seconds.

        .Example
        Invoke-CoffeeWorkloadRead
    #>
    [CmdletBinding()]
    Param()

    try {
        Write-Verbose 'Invoke-CoffeeWorkloadRead: Initializing database connection...'
        Initialize-CoffeeDBConnection

        ## Workflow-3: Get Order
        Write-Verbose 'Invoke-CoffeeWorkloadRead: Retrieving order...'
        Get-CoffeeOrder -OrderID $(Get-CoffeeOrderIDRandom)

    } finally {
        Write-Verbose 'Invoke-CoffeeWorkloadRead: Terminating database connection...'
        Disconnect-CoffeeDBConnection
    }
}