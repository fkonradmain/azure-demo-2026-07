# azure-demo-2026-07

Azure showcase July 2026

## Description

This project is a minor shortcase of a secretless azure kubernetes service deployment. Using azure pipelines - or the local command line -
and OpneTofu (Terraform works as well, but this will collide with the terraform.lock.hcl lockfile), we can generate a cloud environment
that includes the following components:

- AKS Cluster with limited RBAC access
-

## Code layout

### Terraform

The terraform project is subdivided into several

## Execution

### Azure Login

To execute this project, first the boostrap process has to be performed. For that we have to log in to the azure cli first:

```bash
az login
```

During that interactive login dialog, we have to select the correct subscription id.
Optionally, we can now also define a default resource group. Doing that is very useful in this case, since we only use a single
resource group.

```bash
az configure --defaults group="RG-Fabian-Konrad"
```

### Bootstrap procedure

Next, we have to go through the bootstrap procedure. For that, we have to first use the azure cli to set up the Storage account, that we
are going to use for the terraform state files. This storage account will later be managed by terraform as well, hence the very specifics
of its configuration can (and will) be set later.

```bash
az storage account create -n tfstatefk
az storage container create -n tfstatefk --account-name tfstatefk
```

After creating the storage account, we can now run the bootstrap terraform stack.

```bash
# switch working dir to the directory of the bootstrap stack
cd terraform/bootstrap
# Initialize opentofu
tofu init
# Deploy the opentofu resources
tofu apply
```

This will further configure the Opentofu account and grant the github repository permissions to perform actions on the azure resource group.

With the Bootstrap stack deployed onto Azure, we can now deploy the main application stack.

### Main application stack

The main application stack is deployed in the same way as the bootstrap stack:

```bash
# switch working dir to the directory of the app stack
cd terraform/app
# Initialize opentofu
tofu init
# Deploy the opentofu resources
tofu apply
```

It contains far more resources and thus need far longer to deploy. The main stack is prepared to be deployed on other stages as well. For that, we have to provide the environment variable `TF_VAR_deployment_stage` with a different value.

Ideally, in that case, we should also parameterize the terraform initialization procedure to make this stage use a different backend,
so that it does not override the default `dev` state. High level orchestration/helper tools like Terraform Environments or Terragrunt
may be used to ease that process.

### GitHub Actions

The github actions are stored in the `.github/workflows` directory. Currently, only a very simple procedure was set up. It will run
every 24 hours, according to a cron expression, or everytime a commit is performed to the master branch.

Procedurally, the Github actions does the very same steps as described in the main application stack documentation.
Yet non-interactively.

## Project layout

The project contains of two terraform deployments, stored in the terraform directory and additional helper files.

### Terraform Bootstrap Stack

The terraform stack contains every application, that cannot be deployed multiple times. These include a base storage account for the
tarraform state files and the identity federation credentials for the GitHub actions.

### App Stack

The app stack contains all resources needed to deploy one environment of this cluster and its accompanying resources

### Additional files

There are several additional helper files. These are:

- `azure_workload_identity_vault_setup.sh` is a helper file to create service accounts mapped to the specific identity federations that were defined together with the cluster. It also installs the external-secrets-operator
- `external-secret-test.yaml` is a list of examplary resources that can be deployed to check if the external-secrets-operator was deployed correctly.

## Strategies for drift detection

The ideal strategy for drift detection would be using a toolchain that can continuosly track a state of a target application.
For that, we have multiple options.

### Terraform Enterprise

Terraform Enterprise/HCP Terraform(TFE) can be used to make terraform GitOps ready. Terraform enterprise allows regular state validation (every few minutes),
it can be triggered by web hookes (for example triggered from Azure Event Grid) and it can also trigger event hooks itself (for
example after detecting a state drift).

Terraform enterprise can be set up in a way that it has direct access to a git repo, so that there is no point in time, where a one
time event is executed. This means, that we do not need pipeline executions or manual terraform apply runs.
It is even possible to ban terraform apply from being run locally.

### Using a Kubernetes Cluster

We can also use a Kubernetes Cluster to manage terraform resources. For that, we can either use the HCP Terraform Operator, which
de facto is just a kubernetes side management of Terraform Enterprise deployments. Alternatively, we can use the Terraform Provider
for Crossplane.

Both toolings allow use to continuosly track Terraform resources using a Kubernetes cluster. Using a GitOps tool like
ArgoCD or Flux, we can now continuosly check the resources against their desired state, just the same way
as we would, when we deployed a regular helm chart. We can even trigger automatic reconciliation.

As a matter of fact, we can deploy said terraform deployment through a templated helm chart.

## Secretless automation

The deployment pipeline is de facto secretless. The application uses OIDC to validate the GitHub user (which is the identity of the pipeline itself). The GitHub user is then granted special permissions through user federation. In that case, we do not need any long time secrets.
The only secrets needed, are the current JWTs for the GitHub actions.

To give GitHub a chance to actually find the correct Azure Tenant, Azure subscription, Azure resource group and azure location
(which is derived from the resource group), we have to assign these variables in the GitHub repository. These values technically are
not sensitive, but they should not be openly publized.
