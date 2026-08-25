enum SampleStatus {
    Unknown = 0
    Ready = 1
    Failed = 2
}

class SampleBase {
    [string] $Name

    SampleBase([string] $Name) {
        $this.Name = $Name
    }

    [string] GetName() {
        return $this.Name
    }
}

class SampleThing : SampleBase {
    [SampleStatus] $Status = [SampleStatus]::Unknown

    SampleThing([string] $Name) : base($Name) {
        $this.Status = [SampleStatus]::Ready
    }

    [void] Fail() {
        $this.Status = [SampleStatus]::Failed
    }
}
