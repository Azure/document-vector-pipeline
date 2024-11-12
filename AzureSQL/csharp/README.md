# Azure SQL Database, Document to Vector ingestion pipeline Proof-of-concept

## Background
This purpose of this project is to demonstrate a proof of concept pipeline for ingesting content stored in document form (pdf, docx, etc) into Azure SQL database, using the new vector support, for information retrieval.

**Let us know what you think!** Create a GitHub issue for any bugs/feature requests.

### Pipeline stages
The basic stages of the pipeline include:

1. User uploads a file to Azure blob storage.
1. Blob Created Event triggers Azure Function.
1. Azure Function - calls document intelligence service to extract text.
1. Azure Document Intelligence Service - converts the document format into raw text.
1. Azure Function Chunking process- break text into reasonable size chunks for LLMs to process.
1. Azure Functions Generate embedding - using an LLM to produce a vector embedding of the semantics of text chunk.
1. Chunk & Embedding storage - storing each text chunk along with it's embedding in Azure SQL Database for semantic and Full-text searches.

![pipleline](images/azuresql_pipeline.png "Pipeline")

### Technology choices
Currently this proof of concept uses:
* Azure Blob storage for upload of documents.
* Azure Functions to process the pipeline.
* Azure Application Insights for logging.
* Azure Managed Identity to connect resources.
* Azure AI Document Intelligenct for text extraction using the `prebuilt-layout` model.
* Fixed size, non-overlapping text chunking.
* The `text-embedding-3-large` embedding model from Azure OpenAI for embedding.
* Azure SQL Server to store and retrieve vector embeddings.

## Setup

### Prerequisites

* An Azure subscription with access to Azure OpenAI.
* The Azure CLI installed.
* Azure Function Core Tools installed.
* A Powershell prompt.

### Steps

1. Set subscription id and the resource group name that you want to deploy the resources to.:

    ```powershell
    $sub = ""
    $rg = ""
    az account set --subscription $sub    
    ```

1. Create a Resource Group in your Azure subscritpion in the region where you want your resources deployed. Ensure it's a region that supports all of the above Azure Resource types. Examples include `West US`, `East US`, and `East US2`.

    ```powershell
    $l = 'eastus'
    az group create -l $l -n $rg 
    ```

1. Get your Principal ID and set it as a variable

    ```powershell
    $adId = az ad signed-in-user show --query id -o tsv
    ```

1. Set the `baseName` variable to provide a base name for the created resources, and deploy initial set of resources

    ```powershell
    $baseName = 'docai'

    az deployment group create --name "${baseName}deploy" --resource-group $rg --template-file '.\deployment\main.bicep' -p .\deployment\main.bicepparam --parameters userPrincipalId=$adId baseName=$baseName
    ```
    
    This step will likely take several minutes to complete - it will create all of the required Azure resources.

    NOTE: Some resource names must be globally unique. You can set a different base name for the created resources by altering the `baseName` variable value.    

1. Enable access to the managed identity in your Azure SQL database

    1. Navigate to the Azure SQL database account created in the Azure Portal.
    1. Click on the `Query editor(preview)` blade.
    1. Execute the following query to allow the user managed identity that has been createed `<baseName>useridentity` to allow to access Azure SQL.
    ``` SQL
    CREATE USER [docaiuseridentity] FROM EXTERNAL PROVIDER;
    ALTER ROLE db_owner ADD MEMBER [docaiuseridentity];
    ```
    1. See the image below:

    ![screenshot](images/azuresql_managedidentity.png "Enable vector search")

1. Build the Azure Function

    ```powershell
    dotnet publish -c Release
    ```

1. Compress the Azure Function code

    ```powershell
    echo "---> Compressing Function Code"
    Compress-Archive .\DocumentVectorPipelineFunctions\bin\Release\net8.0\* publish.zip
    ```

1. Deploy the functions app code

   ```powershell
    echo "---> Uploading Function Code"
    az functionapp deployment source config-zip -g $rg -n "${baseName}funcapp" --src .\publish.zip
    ```

1. Restart the Azure Function

    ```powershell
    az functionapp restart -g $rg -n "${baseName}funcapp"
    ```

1. Monitor traces
    ```powershell
    # Monitor traces 
    echo "---> Monitoring Function Code"
    func azure functionapp logstream "${baseName}funcapp"
    ```
    Note - `func` above comes from the Azure Functions tools.  You can also view this log stream in the Azure Portal by navigating the the Azure Functions app created above, and clicking on the `Monitoring\Log Stream` blade.

1. Upload documents to Azure blob storage account
    1. Navigate to the storage account created above (`docingblobacc` by default).
    1. Click on the `Storage Browser` blade
    1. Click on `Blob containers` and then the `documents` folder.
    1. Click the `Upload` button in the toolbar, and then drag or browse to a document.
    1. Check the event stream, and your Azure SQL database account. The document should be processed and ingested into a `document` table.

1. Query data

    Build an intelligent, context-aware application using the searchable data in your Azure SQL database account. See the [documentation](https://github.com/Azure-Samples/azure-sql-db-vector-search) for details.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
