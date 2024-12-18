# Specify the directory containing the files
$directory = "C:\Users\pauld\Documents\RealityShaders"

# Get all .fx and .fxh files in the directory
Get-ChildItem $directory -Recurse -Filter "*.fx*" | ForEach-Object {
    $filename = $_.FullName
    
    # Read the entire content of the file
    $content = Get-Content $filename

    # Prepend "#line 2 <filename>" to the content
    $newContent = $content

    # Write the new content back to the file
    Set-Content $filename -Value $newContent -Force
}