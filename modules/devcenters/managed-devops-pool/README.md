# Managed DevOps Pool

Managed DevOps Pool

## Details

{{Add detailed information about the module}}

## Parameters

| Name                         | Type     | Required | Description                                                                            |
| :--------------------------- | :------: | :------: | :------------------------------------------------------------------------------------- |
| `location`                   | `string` | Yes      | Specifies the location for resources.                                                  |
| `poolName`                   | `string` | Yes      | Name of DevCenter                                                                      |
| `subnetId`                   | `string` | Yes      | Subnet id of the subnet the managed pool should be attached to.                        |
| `resourceTags`               | `object` | No       | Tags retrieved from parameter file.                                                    |
| `azdoOrganization`           | `string` | Yes      | Azure DevOps organization (for example the "foo" section of https://dev.azure.com/foo) |
| `devCenterProjectResourceId` | `string` | Yes      | Id of the DevCenter to attach project to.                                              |
| `poolSize`                   | `int`    | No       | Max number of agents.                                                                  |
| `wellKnownImageName`         | `string` | No       | Image to use for pool.                                                                 |
| `sku`                        | `string` | No       | Compute SKU for agent.                                                                 |

## Outputs

| Name | Type | Description |
| :--- | :--: | :---------- |

## Examples

### Example 1

```bicep
```

### Example 2

```bicep
```