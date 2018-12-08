using System.Net;
using System.Text;
using System.IO.Compression;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Primitives;

public static IActionResult Run(HttpRequest req, ILogger log)
{
    string tempPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".zip");
    string language, template_url, nodejs_template_url, dotnet_template_url;
    uint batch, prefetch, checkpoint;
    try
    {
        nodejs_template_url = System.Environment.GetEnvironmentVariable("NODEJS_TEMPLATE_URL", EnvironmentVariableTarget.Process);
        dotnet_template_url = System.Environment.GetEnvironmentVariable("DOTNET_TEMPLATE_URL", EnvironmentVariableTarget.Process);

        if (string.IsNullOrEmpty(req.Query["batch"])
            || string.IsNullOrEmpty(req.Query["prefetch"])
            || string.IsNullOrEmpty(req.Query["checkpoint"])
            || string.IsNullOrEmpty(req.Query["language"])
            || string.IsNullOrEmpty(nodejs_template_url)
            || string.IsNullOrEmpty(dotnet_template_url))
        {
            throw new ArgumentException("supply batch, prefetch, checkpoint, language values. NODEJS_TEMPLATE_URL and DOTNET_TEMPLATE_URL environment variables need to be defined.");
        }

        language = req.Query["language"];
        switch (language)
        {
            case "nodejs":
                template_url = nodejs_template_url;
                break;
            case "dotnet":
                template_url = dotnet_template_url;
                break;
            default:
                throw new ArgumentException("language should be 'nodejs' or 'dotnet'");
        }


        batch = Convert.ToUInt32(req.Query["batch"]);
        prefetch = Convert.ToUInt32(req.Query["prefetch"]);
        checkpoint = Convert.ToUInt32(req.Query["checkpoint"]);

        log.LogInformation($"{language},{batch}, {prefetch}, {checkpoint}");

        // download template first
        using (WebClient myWebClient = new WebClient())
        {
            myWebClient.DownloadFile(template_url, tempPath);
        }
        log.LogInformation($"downloaded {template_url}, saved to {tempPath}");        

        using (MemoryStream zipStream = new MemoryStream())
        {
            zipStream.Write(File.ReadAllBytes(tempPath));
            using (ZipArchive archive = new ZipArchive(zipStream, ZipArchiveMode.Update))
            {
                // delete host.json if exists
                archive.Entries.Where(x => x.Name.Equals("host.json", StringComparison.InvariantCulture))
                        .FirstOrDefault().Delete();

                // read host.template.json
                string hostjsonTemplate = new string(
                    (new System.IO.StreamReader(
                        archive.Entries.Where(x => x.Name.Equals("host.template.json", StringComparison.InvariantCulture))
                        .FirstOrDefault()
                        .Open(), Encoding.UTF8)
                    .ReadToEnd())
                .ToArray());

                //create host.json by applying necessary substitutions to host.template.json
                string hostjson = hostjsonTemplate.Replace("${CHECKPOINT}", checkpoint.ToString())
                    .Replace("${BATCH}", batch.ToString())
                    .Replace("${PREFETCH}", prefetch.ToString());

                // add host.json to the archive
                ZipArchiveEntry hostjsonEntry = archive.CreateEntry("host.json");
                using (StreamWriter writer = new StreamWriter(hostjsonEntry.Open()))
                {
                    writer.Write(hostjson);
                }
            }

            // return archive 
            return new FileContentResult(zipStream.ToArray(), "application/zip") { FileDownloadName = $"deploy-{language}-{batch}-{prefetch}-{checkpoint}.zip" };
        }
    }
    catch (Exception e)
    {
        return new BadRequestObjectResult(e);
    }
    finally
    {
        System.IO.File.Delete(tempPath);
    }
}

