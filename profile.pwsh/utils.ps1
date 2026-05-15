function Merge-PullRequests {
    $prs = gh pr list --json title, number | ConvertFrom-Json;

    foreach ($pr in $prs) {
        if ($Host.UI.PromptForChoice("Merge PR #$($_.number)", "Do you want to merge #$($_.number) '$($_.title)'?", @('&yes', '&no'), 1 ) -eq 0) {
            Write-Host "Merging PR #$($pr.number): $($pr.title)" -ForegroundColor green;
            # gh pr merge $pr.number --squash --delete-branch
        }
    }
}