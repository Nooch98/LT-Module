function size {
    param (
        [string]$ruta = (Get-Location).Path,
        [string]$filtro = "*",
        [string]$buscar = ""
    )

    function Get-FileIcon($extension) {
        $iconos = @{
            ".py" = "[97m[0m"
            ".exe"  = "💻"
            ".mp4"  = "📺"
            ".mp3"  = "🎵"
            ".jpg"  = "📷"
            ".jpeg"  = "📷"
            ".png"  = "📷"
            ".txt"  = "📝"
            ".zip"  = "📦"
            ".ps1"  = "💡"
            ".psm1"  = "💡"
            ".bat"  = "🦇"
            ".rar"  = "📦"
            ".lnk"  = "📎"
            ".js"   = ""
            ".html" = "[33m[0m"
            ".java" = "☕"
            ".css"  = "🎯"
            ".cpp"  = "🔍"
            ".log"  = "📋"
            ".ini"  = "📄"
            ".world" = "🌎"
            ".rdp"  = "🌐"
            ".dll"  = "🧩"
            ".db" = "💽"
            ".nvim" = "✔️"
            ".vim" = "✔️"
            ".json" = "[33m{}[0m"
            ".kbdx" = "🔐"
            ".ico" = "ICO"
        }

        if ($iconos.ContainsKey($extension)) {
            return $iconos[$extension]
        }
        return "📄"
    }

    function Get-FileSize($ruta) {
        $item = Get-Item $ruta

        if ($item.PSIsContainer) {
            $tamano = (Get-ChildItem -Recurse $ruta | Measure-Object -Property Length -Sum).Sum
        } else {
            $tamano = $item.Length
        }

        if ($tamano -ge 1MB) {
            return "{0:N2} MB" -f ($tamano / 1MB)
        }
        elseif ($tamano -ge 1KB) {
            return "{0:N2} KB" -f ($tamano / 1KB)
        }
        else {
            return "${tamano} bytes"
        }
    }

    function Convert-ToUnixPermissions {
        param(
            [string]$permisos
        )

        # Dividir la cadena de permisos en elementos individuales
        $permisosArray = $permisos -split '\r?\n'

        # Mapeo de los permisos de Windows a equivalentes Unix (más completo)
        $mapaPermisos = @{
            'FullControl' = 'rwxrwxrwx'
            'Modify' = 'rw-rw-rw-'
            'ReadAndExecute, Synchronize' = 'r-xr-xr-x'
            'ReadAndExecute' = 'r-xr-xr-x'
            'Read, Synchronize' = 'r--r--r--'
            'Read' = 'r--r--r--'
            'Write' = '-w--w--w-'
            'WriteAttributes' = '---a-----'
            'ReadPermissions' = '---r-----'
            'ReadAttributes' = '---r-----'
            'AppendData' = '--w-------'
            'CreateDirectories' = 'd----d---'
            'CreateFiles' = '----f----'
            'DeleteSubdirectoriesAndFiles' = 'd--x------'
            'Delete' = '----d----'
            'ExecuteFile' = '------x--'
            'ListDirectory' = 'd-l-------'
            'ReadData' = '---------r'
            'ReadExtendedAttributes' = '---------r'
            'Traverse' = '------x--x'
            'WriteData' = '--------w-'
            'WriteExtendedAttributes' = '--------w-'
            # Agregar más mapeos según sea necesario
            # Puedes investigar otros permisos avanzados y añadirlos aquí
        }

        # Lista para almacenar los permisos convertidos
        $permisosUnix = @()

        # Recorrer cada elemento de la lista de permisos de Windows
        foreach ($permiso in $permisosArray) {
            # Dividir el permiso en sus partes (usuario/grupo, permiso, tipo)
            $partesPermiso = $permiso.Trim().Split(' ')

            # Obtener el tipo de permiso (FullControl, Modify, ReadAndExecute, etc.)
            $permisoTipo = $partesPermiso[-1].Trim()

            # Verificar si el tipo de permiso tiene un equivalente en Unix y agregarlo a la lista
            if ($mapaPermisos.ContainsKey($permisoTipo)) {
                $permisosUnix += $mapaPermisos[$permisoTipo]
            } else {
                $permisosUnix += '-----------------'  # Si no hay un mapeo, asignar permisos por defecto
            }
        }

        # Unir los permisos Unix en una sola cadena y devolverla eliminando el prefijo no deseado
        $permisosUnixString = $permisosUnix -join ''
        $startIndex = $permisosUnixString.IndexOf('@') + 3
        $permisosUnixString.Substring($startIndex)
    }


    function Get-FileSecurityInfo($ruta) {
        $infoSeguridad = New-Object -TypeName PSObject -Property @{
            EsEjecutable = $false
            Permisos = "N/A"
        }

        if (Test-Path -Path $ruta -PathType Leaf) {
            $extension = [System.IO.Path]::GetExtension($ruta)

            if ($extension -eq ".exe") {
                $infoSeguridad.EsEjecutable = $true
            }

            try {
                $permisos = (Get-Acl $ruta).AccessToString
                $infoSeguridad.Permisos = $permisos
            } catch {
                $infoSeguridad.Permisos = "Error"
            }
        }

        $infoSeguridad
    }

    function Get-FileHashes($ruta) {
        $hashes = Get-ChildItem -Path $ruta -File | ForEach-Object {
            $hash = Get-FileHash -Path $_.FullName -Algorithm MD5 | Select-Object -ExpandProperty Hash
            $hash
        }
        $hashes
    }

    function Get-FileOrFolderInfo($ruta) {
        $infoItem = New-Object -TypeName PSObject -Property @{
            Icono = $null
            Nombre = $null
            Lineas = $null
            Tamano = $null
            ArchivosEnCarpeta = $null
            InfoSeguridad = $null
            UltimaModificacion = $null
            ArchivosContenidos = $null
            FechaCreacion = $null
            FechaAcceso = $null
            Atributos = $null
            Hash = $null  # Add a new property for hash
        }

        if (Test-Path -Path $ruta -PathType Leaf) {
            $nombre = [System.IO.Path]::GetFileName($ruta)
            $extension = [System.IO.Path]::GetExtension($ruta)
            $icono = Get-FileIcon($extension)

            $tamano = Get-FileSize $ruta
            $infoItem.Icono = $icono
            $infoItem.Nombre = $nombre

            if ($extension -eq ".exe") {
                $infoItem.Lineas = "EXE"
            } else {
                try {
                    $lineas = (Get-Content -Path $ruta -ReadCount 0).Length
                    $infoItem.Lineas = $lineas
                } catch {
                    $infoItem.Lineas = "Error"
                }
            }

            # Obtener info de seguridad
            $infoSeguridad = Get-FileSecurityInfo $ruta
            $infoItem.InfoSeguridad = $infoSeguridad

            # Add hash to the main object
            $infoItem.Hash = (Get-FileHashes $ruta) -join ', '

            $fileInfo = Get-Item $ruta
            $infoItem.Tamano = $tamano
            $infoItem.FechaCreacion = $fileInfo.CreationTime
            $infoItem.FechaAcceso = $fileInfo.LastAccessTime
            $infoItem.Atributos = $fileInfo.Attributes
        } elseif (Test-Path -Path $ruta -PathType Container) {
            $nombre = [System.IO.Path]::GetFileName($ruta)
            $icono = "📁"
            $tamano = Get-FileSize $ruta

            $infoItem.Icono = $icono
            $infoItem.Nombre = $nombre
            $infoItem.Lineas = "Carpeta"
            $infoItem.Tamano = $tamano

            # Contar archivos en la carpeta
            $archivosEnCarpeta = (Get-ChildItem -File -Path $ruta -Filter $filtro).Count
            $infoItem.ArchivosEnCarpeta = $archivosEnCarpeta

            # Obtener nombres de archivos en la carpeta
            $nombresArchivos = (Get-ChildItem -File -Path $ruta | Select-Object -ExpandProperty Name)
            $infoItem.ArchivosContenidos = $nombresArchivos

            $fileInfo = Get-Item $ruta
            $infoItem.UltimaModificacion = $fileInfo.LastWriteTime
        } else {
            Write-Host "Ruta no válida: $ruta"
        }

        $infoItem
    }

    $contenido = Get-ChildItem -Path $ruta -Filter $filtro | Where-Object { $_.Name -like "*$buscar*" }

    $tablaContenido = $contenido | ForEach-Object { Get-FileOrFolderInfo $_.FullName }

    # Modificar la información de permisos para usar el formato UNIX
    $tablaContenido = $tablaContenido | ForEach-Object {
        if ($_.InfoSeguridad -ne $null) {
            $permisosUnix = Convert-ToUnixPermissions -permisos $_.InfoSeguridad.Permisos
            $_.InfoSeguridad = $permisosUnix
        }
        $_  # Se asegura de mantener el objeto con la información modificada o sin cambios
    }

    # Select the properties and convert hash to string
    $tableOutput = $tablaContenido | Select-Object Icono, Nombre, UltimaModificacion, Lineas, Tamano, ArchivosEnCarpeta, InfoSeguridad, @{Name='hash'; Expression={$_.hash -join ', '}}

    # Display the table in the console
    $tableOutput | Format-Table -AutoSize
}
New-Alias -Name lt -Value size
Export-ModuleMember -Function size -Alias lt

