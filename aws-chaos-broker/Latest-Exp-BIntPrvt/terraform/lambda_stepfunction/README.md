# AWS Step Functions – Chaos Experiment Orchestrator

This Terraform module deploys an AWS Step Functions state machine that iterates
over a list of chaos experiments and invokes the existing Lambda handler for
each one. The Lambda function then loads the experiment YAML from S3 and
executes it.

> **Assumptions**
> - The Lambda handler is already deployed (see `Experiment-Broker-Module/experiment_code/lambda/terraform/`).
> - The experiment YAML files referenced in the payload exist in the specified S3 bucket.

---

## Project Layout

```
terraform/lambda_stepfunction/
├── provider.tf             # AWS provider + defaults
├── variables.tf            # Input variables (region, lambda ARN, payload, tags)
├── stepfunction.tf         # IAM role, log group, state machine definition
├── state_machine.json      # ASL template (Map state invoking Lambda)
├── README.md               # This file (how to deploy & test)
```

You can safely remove any files left over from the original `lambda_infra`
module if they are not required for your workflow.

---

## Inputs

| Variable              | Type     | Default                               | Description                              |
|-----------------------|----------|---------------------------------------|------------------------------------------|
| `aws_region`          | string   | `us-east-1`                           | AWS region for all resources             |
| `environment`         | string   | `dev`                                  | Environment tag                          |
| `state_machine_name`  | string   | `chaos-experiment-runner`             | Step Function name                       |
| `lambda_function_arn` | string   | **required**                          | ARN of the chaos-handler Lambda          |
| `payload_template`    | any      | sample payload (see below)            | Default execution payload (optional)     |
| `tags`                | map(any) | `{}`                                  | Extra resource tags                      |

### Sample `payload_template`

```hcl
payload_template = {
  Payload = {
    list = [
      {
        experiment_source = "Demo-Kubernetes(EKS)-Worker Node (Pod)-State-TerminationCrash.yml"
        bucket_name       = "resiliencyvr-package-build-bucket-rich1"
        output_config = {
          S3 = {
            bucket_name = "resiliencyvr-package-build-bucket-rich1"
            path        = "experiment_journals"
          }
          OPENSEARCH = {
            index = "resiliency-experiment-journals"
            host  = "search-resiliency-health-index-5kbdxdwunwcdt7u4ti4musfw34.us-east-1.es.amazonaws.com"
          }
        }
      }
    ]
    state = "pending"
  }
}
```

---

## Step Function Logic

- **HasPayload** – If no payload is provided at execution time, injects the
  `payload_template` as a default.
- **IterateExperiments (Map)** – Loops through `Payload.list` and invokes the
  Lambda for each experiment entry.
  - Lambda payload includes `experiment_source`, `bucket_name`,
    `output_config`, current `state`, and the iteration index.
  - Retries once with exponential backoff.
  - Records success/failure status per experiment.
- **Finalize** – Returns a summary message and the iteration results.

The Lambda handler remains responsible for loading experiment YAML from S3 and
writing results back to the target bucket or downstream systems.

---

## Usage

1. **Populate `terraform.tfvars`**

   ```hcl
   aws_region          = "us-east-1"
   environment         = "dev"
   state_machine_name  = "chaos-experiment-runner"
   lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:chaos-broker-handler"

   payload_template = {
     Payload = {
       list = [
         {
           experiment_source = "Demo-Kubernetes(EKS)-Worker Node (Pod)-State-TerminationCrash.yml"
           bucket_name       = "resiliencyvr-package-build-bucket-demo"
           output_config = {
             S3 = {
               bucket_name = "resiliencyvr-package-build-bucket-demo"
               path        = "experiment_journals"
             }
             OPENSEARCH = {
               index = "resiliency-experiment-journals"
               host  = "search-resiliency-health-index-5kbdxdwunwcdt7u4ti4musfw34.us-east-1.es.amazonaws.com"
             }
           }
         }
       ]
       state = "pending"
     }
   }
   ```

2. **Deploy**

   ```bash
   terraform init
   terraform apply
   ```

3. **Invoke the State Machine**

   - Use the default payload (no input required):
     ```bash
     aws stepfunctions start-execution \
       --state-machine-arn <arn> \
       --name chaos-run-$(date +%s)
     ```

   - Override with a custom payload:
     ```bash
     aws stepfunctions start-execution \
       --state-machine-arn <arn> \
       --name chaos-run-$(date +%s) \
       --input file://payload.json
     ```

   `payload.json` should follow the sample structure:

   ```json
   {
     "Payload": {
       "list": [
         {
           "experiment_source": "Demo-Kubernetes(EKS)-Worker Node (Pod)-State-TerminationCrash.yml",
           "bucket_name": "resiliencyvr-package-build-bucket-demo",
           "output_config": {
             "S3": {
               "bucket_name": "resiliencyvr-package-build-bucket-demo",
               "path": "experiment_journals"
             },
             "OPENSEARCH": {
               "index": "resiliency-experiment-journals",
               "host": "search-resiliency-health-index-5kbdxdwunwcdt7u4ti4musfw34.us-east-1.es.amazonaws.com"
             }
           }
         },
         {
           "experiment_source": "Demo-Kubernetes(EKS)-Worker Node (EC2)-Network-PacketLoss.yml",
           "bucket_name": "resiliencyvr-package-build-bucket-demo",
           "output_config": {
             "S3": {
               "bucket_name": "resiliencyvr-package-build-bucket-demo",
               "path": "experiment_journals"
             },
             "OPENSEARCH": {
               "index": "resiliency-experiment-journals",
               "host": "search-resiliency-health-index-5kbdxdwunwcdt7u4ti4musfw34.us-east-1.es.amazonaws.com"
             }
           }
         }
       ],
       "state": "pending"
     }
   }
   ```

4. **Monitor Execution**

   - AWS Console: Step Functions > Executions
   - CloudWatch Logs: `/aws/vendedlogs/states/<state_machine_name>`

---

## Frequently Asked Questions

**Q: Do I need to rebuild the Lambda package here?**  
No. This module only orchestrates the Lambda already deployed elsewhere. Provide
its ARN via `lambda_function_arn`.

**Q: Where should the experiment YAML files live?**  
In the S3 bucket referenced by each list item (`bucket_name` +
`experiment_source`). The Lambda handler reads them during execution.

**Q: Can I run experiments in parallel?**  
Yes—set `MaxConcurrency` in `state_machine.json` to a higher value (and adjust
Lambda concurrency/limits as appropriate).

---

## Clean Up

Destroy the state machine and supporting resources when you’re done:

```bash
terraform destroy
```

This removes the Step Function, IAM role/policy attachment, and log group.

