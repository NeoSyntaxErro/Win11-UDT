# Powershell Alnternaitve to Python's http.server utility.

param (
    [int]$Port = 8080
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$Port/")
$listener.Start()

Write-Host "Serving directory listing on port $Port ..."
Write-Host "Visit http://localhost:$Port in your browser.`n"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    $urlPath = $request.Url.AbsolutePath.TrimStart('/')
    $localPath = Join-Path (Get-Location) ([Uri]::UnescapeDataString($urlPath) -replace '/', '\')

    if (Test-Path $localPath) {
        $item = Get-Item $localPath -ErrorAction SilentlyContinue

        if ($item -and $item.PSIsContainer) {
            # Directory: List contents
            $entries = Get-ChildItem -Path $item.FullName
            $html = "<html><body><h2>Directory listing for /$urlPath</h2><ul>"

            foreach ($entry in $entries) {
                $name = $entry.Name
                $href = [Uri]::EscapeDataString($name)
                if ($entry.PSIsContainer) { $href += '/' }
                $html += "<li><a href='/$urlPath/$href'>$name</a></li>"
            }

            $html += "</ul></body></html>"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = "text/html"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        else {
            # File: Serve content
            try {
                $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
                $response.ContentType = "application/octet-stream"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } catch {
                $response.StatusCode = 500
                $msg = [System.Text.Encoding]::UTF8.GetBytes("500 Internal Server Error")
                $response.OutputStream.Write($msg, 0, $msg.Length)
            }
        }
    }
    else {
        # Not found
        $response.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
        $response.OutputStream.Write($msg, 0, $msg.Length)
    }

    $response.OutputStream.Close()
}
