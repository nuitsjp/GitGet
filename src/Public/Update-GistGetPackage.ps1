function Update-GistGetPackage {
    [CmdletBinding()]
    param(
    )

    $packageParams = @{}
    if ($Uri) { $packageParams['Uri'] = $Uri }
    if ($Path) { $packageParams['Path'] = $Path }

    [GistGetPackage[]] $gistGetPackages = Get-GistGetPackage @packageParams

    # インストール済みのパッケージを取得
    Write-Host "Getting installed packages..."
    $updatablePackages = Get-WinGetPackage | Where-Object { $_.IsUpdateAvailable }

    $needRebootPackageIds = @()
    
    foreach ($updatablePackage in $updatablePackages) {
        $updatablePackageId = $updatablePackage.Id
        $installedVersion = $updatablePackage.InstalledVersion
        $gistGetPackage = $gistGetPackages | Where-Object { $_.Id -eq $updatablePackageId }
        
        if ($gistGetPackage) {
            # GistGetPackageにパッケージがある場合、バージョンを比較してアップデートするかどうかを判定
            if ($gistGetPackage.Version) {
                # GistGetPackageにバージョンがある場合、バージョンを比較
                if ($gistGetPackage.Version -eq $installedVersion) {
                    # インストール済みのバージョンとGistGetPackageのバージョンが同じ場合はアップデートしない
                    $needUpdate = $false
                } else {
                    # インストール済みのバージョンとGistGetPackageのバージョンが異なる場合は
                    # 置き換えるかどうかを確認する
                    Write-Host "Version mismatch: $updatablePackageId installed version is $installedVersion, but GistGet version is $($gistGetPackage.Version)" -ForegroundColor Yellow
                    Write-Host "Do you want to replace it? (y/n): " -ForegroundColor Yellow -NoNewline
                    $replace = Read-Host
                    if ($replace -eq "y") {
                        # アンインストールしてアップデートする
                        $needUpdate = $false
                        Write-Host "Uninstall package $updatablePackageId"
                        $uninstalled = Uninstall-WinGetPackage -Id $updatablePackageId -Force
                        if ($uninstalled.RebootRequired) {
                            $needRebootPackageIds += $updatablePackageId
                        }

                        Write-Host "Installing package $updatablePackageId"
                        $installed = Install-WinGetPackage -Id $updatablePackageId -Version $gistGetPackage.Version -Force
                        if ($installed.RebootRequired) {
                            # needRebootPackageIdsにすでに追加されている場合は追加しない
                            if ($needRebootPackageIds -contains $updatablePackageId) {
                                $needRebootPackageIds += $updatablePackageId
                            }
                        }
                    } else {
                        $needUpdate = $false
                    }
                }
            }
            else {
                # GistGetPackageにバージョンがない場合は、無条件でアップデートする
                $needUpdate = $true
            }
        } else {
            # GistGetPackageにパッケージがない場合は、無条件でアップデートする
            $needUpdate = $true
        }

        if ($needUpdate) {
            Write-Host "Updating package $updatablePackageId"
            $updated = Update-WinGetPackage -Id $updatablePackageId
            if ($updated.RebootRequired) {
                $needRebootPackageIds += $updatablePackageId
            }
        }
    }

    Write-Host

    # $needRebootPackages にリブートが必要なパッケージがある場合、パッケージIDをすべて表示
    if ($needRebootPackageIds.Count -gt 0) {
        Write-Host "Reboot is required for the following packages:" -ForegroundColor Red
        $needRebootPackageIds | ForEach-Object { Write-Host $_ -ForegroundColor Red }

        # リブートするかどうかを確認
        $reboot = Read-Host "Do you want to reboot now? (y/n)" -ForegroundColor Red
        if ($reboot -eq "y") {
            Write-Host "Rebooting..."
            Restart-Computer -Force
        }
    }
}
