function Merge-PullRequests {
    $prs = gh pr list --limit 100 --json "title,number" | ConvertFrom-Json;

    foreach ($pr in $prs) {
        $d = $Host.UI.PromptForChoice("Merge PR #$($pr.number)", "Do you want to merge #$($pr.number) '$($pr.title)'?", @('&yes', '&no', '&close'), 1 );
        if ($d -eq 0) {
            Write-Host "Merging PR #$($pr.number): $($pr.title)" -ForegroundColor green;
            gh pr merge $pr.number --squash --delete-branch
        }
        elseif ($d -eq 2) {
            Write-Host "Closing PR #$($pr.number): $($pr.title)" -ForegroundColor red;
            gh pr close $pr.number
        }
    }
}
function Remove-PulumiResources ($endsWith) {
    $resources = op run --no-masking -- pulumi stack --show-urns --output json | ConvertFrom-Json -AsHashtable | foreach { $_.resources } | foreach { $_.urn } | where { $_ -like $endsWith };
    $resources = "'$($resources -join "' '")'"

    Write-Host "Processing resources: $($resources)" -ForegroundColor cyan;
    iex "op run --no-masking -- pulumi state delete $resources --yes --target-dependents"
}