function Retry-Command
{
    param (
    [Parameter(Mandatory=$true)][string]$command, 
    [Parameter(Mandatory=$true)][hashtable]$args, 
    [Parameter(Mandatory=$false)][int]$retries = 5, 
    [Parameter(Mandatory=$false)][int]$secondsDelay = 2
    )
    
    # Setting ErrorAction to Stop is important. This ensures any errors that occur in the command are 
    # treated as terminating errors, and will be caught by the catch block.
    $args.ErrorAction = "Stop"
    
    $retrycount = 0
    $completed = $false
    
    while (-not $completed) {
        try {
            & $command @args
            Write-Verbose ("Command [{0}] succeeded." -f $command)
            $completed = $true
        } catch {
            if ($retrycount -ge $retries) {
                Write-Verbose ("Command [{0}] failed the maximum number of {1} times." -f $command, $retrycount)
                throw
            } else {
                Write-Verbose ("Command [{0}] failed. Retrying in {1} seconds." -f $command, $secondsDelay)
                Start-Sleep $secondsDelay
                $retrycount++
            }
        }
    }
}

function Get-UserInput
{
	Param
	(
		[Parameter(Mandatory=$True)]
		[string]$Id,
		[Parameter(Mandatory=$True)]
		[string]$Text,
		[Parameter(Mandatory=$false)]
		[string]$Default
	)
    
    if ($Default) {
        $Text = ($Text + " (Default " + $Default + ")")
    }
    $reply = Get-Variable -name "Hardcode$Id" -ValueOnly -ErrorAction SilentlyContinue
    if ($reply) {
        if ($reply -eq 'default') {
            $Default
        } else {
            $reply
        }
        Write-Host "$Text : $reply"
    } else {
        $reply = Read-Host $Text
        if (!$reply) {
            $Default
        } else {
            $reply
        }
    }
}

function New-NavSharePointApp
{
	Param
	(
		[Parameter(Mandatory=$true)]
		[guid]$newClientId,
		[Parameter(Mandatory=$true)]
		[guid]$newProductId,
		[Parameter(Mandatory=$true)]
		[string]$publicWebBaseUrl,
		[Parameter(Mandatory=$true)]
		[string]$folder,
		[Parameter(Mandatory=$true)]
		[string]$orgAppFileName,
		[Parameter(Mandatory=$true)]
		[string]$newAppFileName,
		[Parameter(Mandatory=$false)]
		[bool]$Multitenant = $false,
		[Parameter(Mandatory=$false)]
		$replacements
	)

    if (!$replacements) {
        $replacements = @()
    }
    if (!$Multitenant) {
        $replacements += @("?tenant={HostUrl}&amp;", "?")
        $replacements += @("?tenant={HostUrl}", "")
    }
    $replacements += @("https://nav80svc.navdemo.net/AAD/WebClient/", $PublicWebBaseUrl)
    $replacements += @('8C49CBD0-7834-4231-B166-2F9408628A9C', $newProductId)
    $replacements += @('EE7C97B1-E374-41F2-9B0E-B98A6FFECBF7', $newClientId)
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Finance Reports"',('"'+$FinanceReportsDescription+'"'))
    $replacements += @('"Finance Reports"',('"'+$FinanceReportsTitle+'"'))
    
    $replacements += @('"Generic Card Part from Microsoft Dynamics NAV"',('"'+$GenericCardDescription+'"'))
    $replacements += @('"Generic Card"',('"'+$GenericCardTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Job WIP Cockpit"',('"'+$JobWipDescription+'"'))
    $replacements += @('"Job WIP Cockpit"',('"'+$JobWipTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Project Billing and Status"',('"'+$ProjectBillingDescription+'"'))
    $replacements += @('"Project Billing And Status"',('"'+$ProjectBillingTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Sales Process"',('"'+$SalesProcessDescription+'"'))
    $replacements += @('"Sales Process"',('"'+$SalesProcessTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Service Process"',('"'+$ServiceProcessDescription+'"'))
    $replacements += @('"Service Process"',('"'+$ServiceProcessTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Trial Balance"',('"'+$TrialBalanceDescription+'"'))
    $replacements += @('"Trial Balance"',('"'+$TrialBalanceTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Finance Performance Chart"',('"'+$FinancePerformanceDescription+'"'))
    $replacements += @('"Finance Performance"',('"'+$FinancePerformanceTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays a generic Chart"',('"'+$GenericChartDescription+'"'))
    $replacements += @('"Generic Chart"',('"'+$GenericChartTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Purchase Performance Chart"',('"'+$PurchasePerformanceDescription+'"'))
    $replacements += @('"Purchase Performance"',('"'+$PurchasePerformanceTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Sales Performance Chart"',('"'+$SalesPerformanceDescription+'"'))
    $replacements += @('"Sales Performance"',('"'+$SalesPerformanceTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Trailing Sales Orders Chart"',('"'+$TrailingSalesOrdersDescription+'"'))
    $replacements += @('"Trailing Sales Orders"',('"'+$TrailingSalesOrdersTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Customer List"',('"'+$CustomersDescription+'"'))
    $replacements += @('"Customers"',('"'+$CustomersTitle+'"'))
    
    $replacements += @('"Generic List Page from Microsoft Dynamics NAV"',('"'+$GenericListDescription+'"'))
    $replacements += @('"Generic List"',('"'+$GenericListTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Item List"',('"'+$ItemsDescription+'"'))
    $replacements += @('"Items"',('"'+$ItemsTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Job List"',('"'+$JobsDescription+'"'))
    $replacements += @('"Jobs"',('"'+$JobsTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Payables"',('"'+$PayablesDescription+'"'))
    $replacements += @('"Payables"',('"'+$PayablesTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Receivables"',('"'+$ReceivablesDescription+'"'))
    $replacements += @('"Receivables"',('"'+$ReceivablesTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Sales Invoice List"',('"'+$SalesInvoicesDescription+'"'))
    $replacements += @('"Sales Invoices"',('"'+$SalesInvoicesTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Sales Orders List"',('"'+$SalesOrdersDescription+'"'))
    $replacements += @('"Sales Orders"',('"'+$SalesOrdersTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Service Orders"',('"'+$ServiceOrdersDescription+'"'))
    $replacements += @('"Service Orders"',('"'+$ServiceOrdersTitle+'"'))
    
    $replacements += @('"App Part from Microsoft Dynamics NAV which displays the Vendor List"',('"'+$VendorsDescription+'"'))
    $replacements += @('"Vendors"',('"'+$VendorsTitle+'"'))
    
    $replacements += @('"Page number."',('"'+$PageNumberStr+'"'))
    $replacements += @('"Show UI parts, e.g., factboxes?"',('"'+$ShowUiPartsStr+'"'))
    $replacements += @('"Set the page size in number of rows."',('"'+$SetThePageSizeStr+'"'))
    
    $replacements += @("Microsoft Dynamics NAV for Office 365", $ProductName)
   
    $orgAppFileName = Join-Path $folder $orgAppFileName
    
    if (Test-Path -Path $orgAppFileName)
    {
        $tmpFolder = (Join-Path $folder "tmp")
        Remove-Item $tmpFolder -Recurse -ErrorAction Ignore
        New-Item $tmpFolder -ItemType directory
    
        $shell = new-object -com shell.application
        $appname = Join-Path $tmpFolder $newAppFileName
        New-Item $appname -ItemType file -Force
    
        $orgzip = $shell.NameSpace($orgAppFileName)
        $newzip = $shell.NameSpace($appname)
    
        foreach($item in $orgzip.items()) {
            $shell.NameSpace($tmpFolder).Copyhere($item, 16+4)
            $filename = $item.Path.ToLower().Replace($orgAppFileName.ToLower(), $tmpFolder)
            if ($item.Path.EndsWith(".xml")) {
                if (!$item.Path.EndsWith("].xml")) {
                    $content = (Get-Content $filename | Out-String)
                    for ($i=0; $i -lt $replacements.Length; $i += 2) {
                        $content = $content.Replace( $replacements[$i], $replacements[$i+1] )
                    }
                    $content | out-file $filename -Force -Encoding utf8
                }
            }
            $newzip.CopyHere($filename, 16+4)
            Start-Sleep -s 5
        }
    
        Copy-Item $appname (Join-Path $folder $newAppFileName)
        Remove-Item $tmpFolder -Recurse
    }
}

function Decrypt-SecureString {
    param(
        [Parameter(Mandatory=$true)]
        [System.Security.SecureString]
        $sstr
    )

    $marshal = [System.Runtime.InteropServices.Marshal]
    $ptr = $marshal::SecureStringToBSTR( $sstr )
    $str = $marshal::PtrToStringBSTR( $ptr )
    $marshal::ZeroFreeBSTR( $ptr )
    $str
} 

function Set-TopNavigationShared {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SharePointLoginname,
        [Parameter(Mandatory=$true)]
        [SecureString]$SharePointSecurePassword,
        [Parameter(Mandatory=$true)]
        [string]$subSiteUrl
    )
    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($subSiteUrl)
    $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($SharePointLoginname, $SharePointSecurePassword)
    $context.RequestTimeOut = 5000 * 60 * 10;
    $web = $context.Web
    $site = $context.Site
    $navigation = $web.Navigation
    $context.Load($web)
    $context.Load($site)
    $context.Load($navigation)
    $context.ExecuteQuery()
    $navigation.UseShared = $true
    $context.Load($navigation)
    $Context.ExecuteQuery()
}

function Remove-TopNavigationNodes {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SharePointLoginname,
        [Parameter(Mandatory=$true)]
        [SecureString]$SharePointSecurePassword,
        [Parameter(Mandatory=$true)]
        [string]$siteUrl
    )
    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl)
    $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($SharePointLoginname, $SharePointSecurePassword)
    $context.RequestTimeOut = 5000 * 60 * 10;
    $web = $context.Web
    $site = $context.Site
    $navigation = $web.Navigation
    $topNavigationBar = $navigation.TopNavigationBar
    $context.Load($web)
    $context.Load($site)
    $context.Load($navigation)
    $context.Load($topNavigationBar)
    $context.ExecuteQuery()
    if ($topNavigationBar.Count -gt 0) {
        while ($topNavigationBar.Count -gt 0) {
            $topNavigationBar[0].DeleteObject()
        }
        $Context.ExecuteQuery();
    }
}

function Add-TopNavigationNode {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SharePointLoginname,
        [Parameter(Mandatory=$true)]
        [SecureString]$SharePointSecurePassword,
        [Parameter(Mandatory=$true)]
        [string]$siteUrl,
        [Parameter(Mandatory=$true)]
        [string]$title,
        [Parameter(Mandatory=$true)]
        [string]$url,
        [Parameter(Mandatory=$true)]
        [bool]$isExternal
    )
    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl)
    $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($SharePointLoginname, $SharePointSecurePassword)
    $context.RequestTimeOut = 5000 * 60 * 10;
    $web = $context.Web
    $site = $context.Site
    $navigation = $web.Navigation
    $topNavigationBar = $navigation.TopNavigationBar
    $context.Load($web)
    $context.Load($site)
    $context.Load($navigation)
    $context.Load($topNavigationBar)
    $context.ExecuteQuery()
    $NavigationNode = New-Object Microsoft.SharePoint.Client.NavigationNodeCreationInformation
    $NavigationNode.Title = $title
    $NavigationNode.Url = $url
    $NavigationNode.AsLastNode = $true	
    $NavigationNode.IsExternal = $isExternal
    $Context.Load($topNavigationBar.Add($NavigationNode))
    $Context.ExecuteQuery()
}

function Add-WarmupPages {
	Param
	(
		[Parameter(Mandatory=$True)]
		[string]$Path
    )

    $Pages = "C:\DEMO\WarmupNAV\Pages.txt"
    $WarmupPages = Get-Content -Path $Pages
    Get-Content -Path $Path | % {
        if (!$WarmupPages.Contains($_)) {
            $WarmupPages += $_
        }
    }
    $WarmupPages | Set-Content -Path $Pages
}
