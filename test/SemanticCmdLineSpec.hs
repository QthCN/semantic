import Language
       \/ cons0 (ParseFixture (jsonParseTree (ParseCommit "2e4144eb8c44f007463ec34cb66353f0041161fe" [("not-a-file.rb", Just Ruby)]) repo []) emptyJsonParseTreeOutput)
       \/ cons0 (ParseFixture (jsonParseTree (ParsePaths [("not-a-file.rb", Just Ruby)]) repo []) emptyJsonParseTreeOutput)
      pathMode = ParsePaths [("test/fixtures/ruby/and-or.A.rb", Just Ruby)]
      pathMode' = ParsePaths [("test/fixtures/ruby/and-or.A.rb", Just Ruby), ("test/fixtures/ruby/and-or.B.rb", Just Ruby)]
      commitMode = ParseCommit "2e4144eb8c44f007463ec34cb66353f0041161fe" [("methods.rb", Just Ruby)]
      pathMode = DiffPaths ("test/fixtures/ruby/method-declaration.A.rb", Just Ruby) ("test/fixtures/ruby/method-declaration.B.rb", Just Ruby)
      commitMode = DiffCommits "dfac8fd681b0749af137aebf3203e77a06fbafc2" "2e4144eb8c44f007463ec34cb66353f0041161fe" [("methods.rb", Just Ruby)]
