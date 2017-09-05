using Microsoft.Owin;
using Owin;

[assembly: OwinStartupAttribute(typeof(DeploymentSlotDemo.Startup))]
namespace DeploymentSlotDemo
{
    public partial class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            ConfigureAuth(app);
        }
    }
}
