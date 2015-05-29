function Get-UserInput {
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
