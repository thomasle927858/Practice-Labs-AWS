# Create a custom Identity and Access Management (IAM) policy
## Requirements
The IAM policy should allow full access to Amazon EC2, subject to the following conditions:
- The `ec2:InstanceType` must be `t3.micro` AND
- The `aws:RequestedRegion` must be in one of the following regions: `["us-west-1", "us-west-2", "us-east-1", "us-east-2"]`

Restricting the EC2 instance type may help to manage costs. Restricting EC2 access to regions located in a country may be required for compliance purposes.

## Policy
The IAM policy can be found in the file `custom-IAM-policy.json`.

## References
https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-requestedregion
https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_multi-value-conditions.html
https://wellarchitectedlabs.com/cost/200_labs/200_2_cost_and_usage_governance/2_ec2_restrict_region/
https://wellarchitectedlabs.com/cost/200_labs/200_2_cost_and_usage_governance/4_ec2_restrict_size/
