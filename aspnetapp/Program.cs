using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Server.Kestrel.Https;
using Microsoft.Extensions.Hosting;
using System;
using System.IO;
using System.Security.Cryptography.X509Certificates;

namespace aspnetapp
{
	public class Program
	{
		public static void Main(string[] args)
		{
			CreateHostBuilder(args).Build().Run();
		}

		public static IHostBuilder CreateHostBuilder(string[] args) =>
			Host.CreateDefaultBuilder(args)
				.ConfigureWebHostDefaults(webBuilder =>
				{
					webBuilder
						.UseStartup<Startup>()
						.UseKestrel(options =>
						{
							options.ConfigureHttpsDefaults(ConfigureHttps);
						});
				});

		private static void ConfigureHttps(HttpsConnectionAdapterOptions options)
		{
			try
			{
				// When we get the certificate from Key Vault as a secret,
				// it provides the entire PFX file but without the password.
				// Since PFX is a binary format and a secret is a string,
				// it is base64 encoded. So we read in the text file and convert
				// it to the bytes to initialize the X509Certificate2.
				var certPath = Environment.GetEnvironmentVariable("HTTPS_CERTIFICATE_PATH");
				if (!string.IsNullOrEmpty(certPath))
				{
					var certString = System.IO.File.ReadAllText(certPath);
					var certBytes = Convert.FromBase64String(certString);
					var httpsCert = new X509Certificate2(certBytes);

					Console.WriteLine($"HTTPS cert Subject:    {httpsCert.Subject}");
					Console.WriteLine($"HTTPS cert Thumbprint: {httpsCert.Thumbprint}");

					// set the Kestrel HTTPS certificate
					options.ServerCertificate = httpsCert;
				}
			}
			catch (Exception ex)
			{
				Console.Error.WriteLine($"unable to load https cert: {ex}");
				throw;
			}
		}
	}
}