<#
    .SYNOPSIS
      Runs a Git command on the current branch that displays all commits
      in ascending order that haven't been merged into develop

    .EXAMPLE
      code-review
      # Displays differences between the current branch and origin/develop    

    .EXAMPLE 
      code-review feature/differentbasebranch
      # Displays differences between the current branch and feature/differentbasebranch
	  
	.EXAMPLE 
      code-review 7bcedc50adfbddffd7e5918a457b5f0d807a68d1
      # Displays the changes after the specified commit up to the head of the current branch

    .EXAMPLE 
      code-review -OriginalBranch feature/differentbasebranch
      # Displays differences between the current branch and feature/differentbasebranch
  #>
function code-review {

    param ( 
        $OriginalBranch = "origin/develop"
    )

	# Need to use Invoke-Expression otherwise the parameter stops git log working correctly
	Invoke-Expression "git log $OriginalBranch..head --name-status --reverse > Review_Summary.diff"
	Invoke-Expression "git log $OriginalBranch..head -p --reverse > Review_Log.diff"
	Invoke-Expression "git diff $OriginalBranch..head -p --reverse > Review_Diff.diff"
	
	if (Get-Command "notepad++" -ErrorAction SilentlyContinue) 
	{
		notepad++ Review_Summary.diff
		notepad++ Review_Log.diff
		notepad++ Review_Diff.diff
	}
}

# source ref: https://lukemerrett.com/code-review-helper-function/