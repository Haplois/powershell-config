using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;

public class DarcCompletion
{
    public readonly bool CanComplete;
    private readonly Assembly darcAssembly;
    private readonly Type[] darcAvailableCommands;
    public readonly IReadOnlyDictionary<string, Verb> Verbs;
    private Dictionary<string, Repository> Repositories = null;

    public DarcCompletion(string assemblyPath)
    {
        darcAssembly = Assembly.LoadFrom(assemblyPath);
        var darcOptions = darcAssembly.EntryPoint?.DeclaringType.GetMethod("GetOptions", BindingFlags.DeclaredOnly | BindingFlags.NonPublic | BindingFlags.Static);
        if (darcOptions == null)
        {
            CanComplete = false;
            darcAvailableCommands = new Type[0];
            Verbs = new ReadOnlyDictionary<string, Verb>(new Dictionary<string, Verb>());
            return;
        }

        darcAvailableCommands = (Type[])darcOptions.Invoke(null, null);
        var verbs = new Dictionary<string, Verb>();

        foreach (var command in darcAvailableCommands)
        {
            var verb = new Verb(command);
            verbs.Add(verb.Name, verb);
        }

        Verbs = new ReadOnlyDictionary<string, Verb>(verbs);
        CanComplete = true;

        // Lazy load repos
        Task.Run(() => GetRepositories());
    }

    public string[] Complete(string commandName, string wordToComplete, int position)
    {
        if (!CanComplete)
        {
            return new string[0];
        }

        var tokens = TokenizeCommand(commandName, position);
        
        System.IO.File.AppendAllLines(@"C:\Users\medenibaykal\Desktop\darc.txt", new[] {
            $"{commandName}, {wordToComplete}, {position}"
        });
        System.IO.File.AppendAllLines(@"C:\Users\medenibaykal\Desktop\darc.txt",
            tokens.Select(i => $"  {i.Type} ({i.Value})")
        );

        var activeToken = tokens.LastOrDefault();

        if (activeToken == null || activeToken.Type == "darc")
        {
            return Verbs.Select(i => i.Key).ToArray();
        }

        if (activeToken.Type == "verb")
        {
            return Verbs.Select(i => i.Key).Where(i => activeToken.Value == string.Empty || i.StartsWith(activeToken.Value, StringComparison.InvariantCultureIgnoreCase)).ToArray();
        }

        if (activeToken.Type == "option")
        {
            var verb = Verbs.SingleOrDefault(i => i.Key.Equals(activeToken.PreviousToken.Value, StringComparison.InvariantCultureIgnoreCase)).Value;
            if (verb == null)
            {
                return new string[0];
            }

            string[] completions = null;
            if (!activeToken.Value.StartsWith("--") && activeToken.Value != string.Empty)
            {
                completions = verb.Options.Select(i => $"-{i.ShortName}").Where(i => activeToken.Value == string.Empty || i.StartsWith(activeToken.Value, StringComparison.InvariantCultureIgnoreCase)).ToArray();
            }

            if (completions == null || completions.Length == 0)
            {
                completions = verb.Options.Select(i => $"--{i.LongName}").Where(i => activeToken.Value == string.Empty || i.StartsWith(activeToken.Value, StringComparison.InvariantCultureIgnoreCase)).ToArray();
            }

            return completions;
        }

        if (activeToken.Type == "repo-name")
        {
            return GetRepositories()
                .Where(i => i.Key.Contains(activeToken.Value) || activeToken.Value == string.Empty)
                .Select(i => i.Key)
                .ToArray();

        }

        return new string[0];
    }

    public Dictionary<string, Repository> GetRepositories()
    {
        if (Repositories != null)
        {
            return Repositories;
        }

        var repositories = new Dictionary<string, Repository>();
        var remoteFactoryType = darcAssembly.GetType("Microsoft.DotNet.Darc.Helpers.RemoteFactory");
        if (remoteFactoryType == null)
        {
            return repositories;
        }

        var commandLineOptions = Activator.CreateInstance(Verbs["get-subscriptions"].Command);
        var remoteFactory = Activator.CreateInstance(remoteFactoryType, commandLineOptions);

        // var remote = await remoteFactory.GetBarOnlyRemoteAsync(null)
        var getBarOnlyRemoteAsyncMethod = remoteFactoryType.GetMethod("GetBarOnlyRemoteAsync");
        var remoteAsync = getBarOnlyRemoteAsyncMethod.Invoke(remoteFactory, new object[] { null });
        var resultMethod = remoteAsync.GetType().GetProperty("Result");
        var remote = resultMethod.GetValue(remoteAsync);

        // var repositoriesAsync = remote.GetBarOnlyRemoteAsync(null, null);
        var remoteType = remote.GetType();
        var repositoriesAsync = remoteType
            .GetMethod("GetRepositoriesAsync")
            .Invoke(remote, new object[] { null, null });

        // IEnumerable remoteRepositories = await repositoriesAsync;
        var repositoriesAsyncType = repositoriesAsync.GetType();
        repositoriesAsyncType.GetMethod("Wait", new Type[0]).Invoke(repositoriesAsync, new object[0]);
        IEnumerable remoteRepositories = (IEnumerable)repositoriesAsyncType.GetProperty("Result").GetValue(repositoriesAsync);

        PropertyInfo repositoryProperty = null, branchProperty = null;
        foreach (object repository in remoteRepositories)
        {
            if (repositoryProperty == null)
            {
                var repositoryType = repository.GetType();
                repositoryProperty = repositoryType.GetProperty("Repository");
                branchProperty = repositoryType.GetProperty("Branch");
            }

            string repoName = (string)repositoryProperty.GetValue(repository),
                   branchName = (string)branchProperty.GetValue(repository);

            Repository repo;

            if (repositories.ContainsKey(repoName))
            {
                repo = repositories[repoName];
            }
            else
            {
                repositories[repoName] = repo = new Repository(repoName);
            }

            if (!repo.Branches.Contains(branchName))
            {
                repo.Branches.Add(branchName);
            }
        }

        Repositories = repositories;
        return repositories;
    }

    private static Token[] TokenizeCommand(string commandName, int position)
    {
        var segments = ParseCommand(commandName, position);
        var tokens = new List<Token>();
        Token lastOption = null;
        for (int i = 0; i < segments.Length; i++)
        {
            var segment = segments[i];

            if (i == 0)
            {
                tokens.Add(new Token("darc", segment, null));
            }
            else if (i == 1)
            {
                tokens.Add(new Token("verb", segment, tokens[0]));
            }
            else if (segment.StartsWith("-") || (lastOption == null && segment == string.Empty))
            {
                lastOption = new Token("option", segment, tokens[1]);
                tokens.Add(lastOption);
            }
            else
            {
                if (lastOption.Value.Contains("repo"))
                {
                    tokens.Add(new Token("repo-name", segment, lastOption));
                }
                else
                {
                    tokens.Add(new Token("value", segment, lastOption));
                }
            }
        }

        return tokens.ToArray();
    }

    private static string[] ParseCommand(string commandName, int position)
    {
        var segments = new List<string>();
        var start = 0;
        var escaping = false;
        var inQuotes = false;
        var captureSegment = false;
        var addExtraSegment = false;

        if (position > commandName.Length)
        {
            position = commandName.Length;
            addExtraSegment = true;
        }

        for (var i = 0; i < position; i++)
        {
            if (escaping)
            {
                escaping = false;
                continue;
            }

            switch (commandName[i])
            {
                case '`':
                    escaping = true;
                    continue;

                case '"':
                    if (inQuotes)
                    {
                        i++;
                        captureSegment = true;
                        inQuotes = false;
                    }
                    else
                    {
                        inQuotes = true;
                        continue;
                    }

                    break;

                case ' ':
                    if (inQuotes)
                    {
                        continue;
                    }
                    captureSegment = true;
                    break;
            }

            if (i == position - 1)
            {
                captureSegment = true;
                i++;
            }

            if (captureSegment)
            {
                var segment = commandName.Substring(start, i - start);
                segments.Add(segment);
                captureSegment = false;
                start = i;

                if (commandName.Length > start && commandName[start] == ' ')
                {
                    start++;
                    continue;
                }
            }
        }

        if (addExtraSegment)
        {
            segments.Add(string.Empty);
        }

        return segments.ToArray();
    }

    private class Token
    {
        public Token(string type, string value, Token previousToken)
        {
            Type = type;
            Value = value;
            PreviousToken = previousToken;
        }

        public string Type { get; }
        public string Value { get; }
        public Token PreviousToken { get; }
    }

    public class Verb
    {
        public Verb(Type command)
        {
            var attributesData = command.GetCustomAttributesData().SingleOrDefault(i => i.AttributeType.Name == "VerbAttribute");
            if (attributesData == null)
            {
                throw new InvalidOperationException($"{command.GetType().FullName} is not a Verb.");
            }

            Name = (string)attributesData.ConstructorArguments[0].Value;
            Command = command;
            foreach (var arg in attributesData.NamedArguments)
            {
                if (arg.MemberName == "HelpText")
                {
                    HelpText = (string)arg.TypedValue.Value;
                }
                else if (arg.MemberName == "Hidden")
                {
                    Hidden = arg.TypedValue.Value is bool ? (bool)arg.TypedValue.Value : false;
                }
            }

            Options = LoadOptions(command.GetProperties(BindingFlags.Instance | BindingFlags.Public));
        }

        private Option[] LoadOptions(PropertyInfo[] propertyInfos)
        {
            var options = new List<Option>();

            foreach (var property in propertyInfos)
            {
                var attributeData = property.GetCustomAttributesData().SingleOrDefault(i => i.AttributeType.Name == "OptionAttribute");
                if (attributeData == null)
                {
                    continue;
                }
                var option = new Option(attributeData);
                options.Add(option);
            }

            return options.ToArray();
        }

        public string Name { get; }
        public Type Command { get; }
        public string HelpText { get; } = string.Empty;
        public bool Hidden { get; } = false;
        public Option[] Options { get; }
    }

    public class Option
    {
        public Option(CustomAttributeData attributeData)
        {
            var parameters = attributeData.Constructor.GetParameters();
            for (int i = 0; i < parameters.Length; i++)
            {

                var key = parameters[i].Name;
                var value = attributeData.ConstructorArguments[i].Value;

                if (key == "longName")
                {
                    LongName = (string)value;
                }
                else if (key == "shortName")
                {
                    ShortName = value.ToString();
                }
            }

            if (LongName == null && ShortName == null)
            {
                LongName = ShortName = string.Empty;
            }
            else if (LongName == null)
            {
                LongName = ShortName;
            }
            else if (ShortName == null)
            {
                ShortName = string.Empty;
            }

            foreach (var arg in attributeData.NamedArguments)
            {
                if (arg.MemberName == "HelpText")
                {
                    HelpText = (string)arg.TypedValue.Value;
                }
                else if (arg.MemberName == "Hidden")
                {
                    Hidden = arg.TypedValue.Value is bool ? (bool)arg.TypedValue.Value : false;
                }
            }
        }

        public string LongName { get; }
        public string ShortName { get; }
        public string SetName { get; } = string.Empty;
        public string HelpText { get; } = string.Empty;
        public bool Hidden { get; } = false;
    }

    public class Repository
    {
        public Repository(string remote)
        {
            Remote = remote;
        }

        public string Remote { get; }
        public List<string> Branches { get; } = new List<string>();
    }
}
