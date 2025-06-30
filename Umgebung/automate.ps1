# PowerShell-Skript zur Erstellung von 3 Windows Server 2025 Hyper-V VMs
# Erstellt am: 30. Juni 2025

# Überprüfung der Hyper-V Module
if (!(Get-Module -ListAvailable -Name Hyper-V)) {
    Write-Error "Hyper-V PowerShell Module ist nicht verfügbar. Bitte installieren Sie das Hyper-V Feature."
    exit
}

# Import Hyper-V Module
Import-Module Hyper-V

# Konfigurationsparameter
$SwitchName = "Interner Switch"
$VMNames = @("Server-01", "Server-02", "Server-03")
$VMPath = "C:\Hyper-V\VMs"
$VHDPath = "C:\Hyper-V\VHDs"
$ISOPath = "C:\ISO\WindowsServer2025.iso"  # Pfad zur Windows Server 2025 ISO anpassen
$Memory = 64GB
$ProcessorCount = 2
$VHDSize = 60GB
$Generation = 2

# Erstelle Verzeichnisse falls sie nicht existieren
if (!(Test-Path $VMPath)) {
    New-Item -Path $VMPath -ItemType Directory -Force
    Write-Host "VM-Verzeichnis erstellt: $VMPath" -ForegroundColor Green
}

if (!(Test-Path $VHDPath)) {
    New-Item -Path $VHDPath -ItemType Directory -Force
    Write-Host "VHD-Verzeichnis erstellt: $VHDPath" -ForegroundColor Green
}

# Überprüfe ob ISO-Datei existiert
if (!(Test-Path $ISOPath)) {
    Write-Warning "ISO-Datei nicht gefunden unter: $ISOPath"
    Write-Host "Bitte laden Sie die Windows Server 2025 ISO herunter und passen Sie den Pfad im Skript an."
}

Write-Host "Starte Hyper-V VM Erstellung..." -ForegroundColor Cyan

# 1. Erstelle virtuellen Switch "Interner Switch"
Write-Host "Erstelle virtuellen Switch: $SwitchName" -ForegroundColor Yellow

try {
    $ExistingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if ($ExistingSwitch) {
        Write-Host "Virtueller Switch '$SwitchName' existiert bereits." -ForegroundColor Green
    }
    else {
        New-VMSwitch -Name $SwitchName -SwitchType Internal
        Write-Host "Virtueller Switch '$SwitchName' erfolgreich erstellt." -ForegroundColor Green
    }
}
catch {
    Write-Error "Fehler beim Erstellen des virtuellen Switches: $_"
    exit
}

# 2. Erstelle die 3 VMs
foreach ($VMName in $VMNames) {
    Write-Host "Erstelle VM: $VMName" -ForegroundColor Yellow
    
    try {
        # Überprüfe ob VM bereits existiert
        $ExistingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if ($ExistingVM) {
            Write-Host "VM '$VMName' existiert bereits. Überspringe..." -ForegroundColor Yellow
            continue
        }
        
        # VHD-Pfad für diese VM
        $VMVHDPath = Join-Path $VHDPath "$VMName.vhdx"
        
        # Erstelle neue VHD
        Write-Host "  - Erstelle VHD: $VMVHDPath" -ForegroundColor Gray
        New-VHD -Path $VMVHDPath -SizeBytes $VHDSize -Dynamic
        
        # Erstelle neue VM
        Write-Host "  - Erstelle VM mit folgenden Spezifikationen:" -ForegroundColor Gray
        Write-Host "    * Generation: $Generation" -ForegroundColor Gray
        Write-Host "    * Arbeitsspeicher: $($Memory / 1GB) GB" -ForegroundColor Gray
        Write-Host "    * Prozessoren: $ProcessorCount" -ForegroundColor Gray
        Write-Host "    * Festplatte: $($VHDSize / 1GB) GB" -ForegroundColor Gray
        
        $VM = New-VM -Name $VMName `
            -Path $VMPath `
            -MemoryStartupBytes $Memory `
            -VHDPath $VMVHDPath `
            -Generation $Generation `
            -SwitchName $SwitchName
        
        # Konfiguriere VM-Einstellungen
        Write-Host "  - Konfiguriere VM-Einstellungen..." -ForegroundColor Gray
        
        # Setze Prozessoranzahl
        Set-VMProcessor -VMName $VMName -Count $ProcessorCount
        
        # Aktiviere dynamischen Arbeitsspeicher (optional)
        Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes 2GB -MaximumBytes $Memory
        
        # Konfiguriere für Generation 2 VMs
        if ($Generation -eq 2) {
            # Aktiviere sicheren Start (kann deaktiviert werden falls nötig)
            Set-VMFirmware -VMName $VMName -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
            
            # Setze Boot-Reihenfolge (DVD zuerst für Installation)
            if (Test-Path $ISOPath) {
                Add-VMDvdDrive -VMName $VMName -Path $ISOPath
                $DVDDrive = Get-VMDvdDrive -VMName $VMName
                $HardDrive = Get-VMHardDiskDrive -VMName $VMName
                Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive
                Write-Host "  - ISO-Datei eingebunden: $ISOPath" -ForegroundColor Gray
            }
        }
        
        # Aktiviere erweiterte Features
        Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
        Enable-VMIntegrationService -VMName $VMName -Name "Heartbeat"
        Enable-VMIntegrationService -VMName $VMName -Name "Key-Value Pair Exchange"
        Enable-VMIntegrationService -VMName $VMName -Name "Shutdown"
        Enable-VMIntegrationService -VMName $VMName -Name "Time Synchronization"
        Enable-VMIntegrationService -VMName $VMName -Name "VSS"
        
        Write-Host "VM '$VMName' erfolgreich erstellt!" -ForegroundColor Green
        
    }
    catch {
        Write-Error "Fehler beim Erstellen der VM '$VMName': $_"
    }
}

# Zusammenfassung anzeigen
Write-Host "`n=== ZUSAMMENFASSUNG ===" -ForegroundColor Cyan
Write-Host "Virtueller Switch: $SwitchName" -ForegroundColor White
Write-Host "Anzahl VMs: $($VMNames.Count)" -ForegroundColor White
Write-Host "VM-Namen: $($VMNames -join ', ')" -ForegroundColor White
Write-Host "Arbeitsspeicher pro VM: $($Memory / 1GB) GB" -ForegroundColor White
Write-Host "Prozessoren pro VM: $ProcessorCount" -ForegroundColor White
Write-Host "Festplattengröße pro VM: $($VHDSize / 1GB) GB" -ForegroundColor White
Write-Host "Generation: $Generation" -ForegroundColor White

# Zeige Status der erstellten VMs
Write-Host "`n=== VM STATUS ===" -ForegroundColor Cyan
foreach ($VMName in $VMNames) {
    $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($VM) {
        Write-Host "$VMName`: $($VM.State)" -ForegroundColor $(if ($VM.State -eq 'Off') { 'Yellow' } else { 'Green' })
    }
}

Write-Host "`n=== NÄCHSTE SCHRITTE ===" -ForegroundColor Cyan
Write-Host "1. Stellen Sie sicher, dass die Windows Server 2025 ISO-Datei verfügbar ist" -ForegroundColor White
Write-Host "2. Starten Sie die VMs über Hyper-V Manager oder mit: Start-VM -Name <VMName>" -ForegroundColor White
Write-Host "3. Installieren Sie Windows Server 2025 Desktop Datacenter Edition" -ForegroundColor White
Write-Host "4. Verwenden Sie das Standardpasswort: Pa`$`$w0rd" -ForegroundColor White
Write-Host "5. Konfigurieren Sie die Netzwerkeinstellungen nach Bedarf" -ForegroundColor White

Write-Host "`nPowerShell-Befehle zum Starten der VMs:" -ForegroundColor Cyan
foreach ($VMName in $VMNames) {
    Write-Host "Start-VM -Name '$VMName'" -ForegroundColor Gray
}

Write-Host "`nSkript abgeschlossen!" -ForegroundColor Green