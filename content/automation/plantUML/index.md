
---
title: "PlantUML for DevOps Documentation in Practice"
summary: “Diagram as Code” approach to automate, standardize, and version technical documentation."
---

PlantUML enables teams to automate and standardize technical documentation through a “Diagram as Code” approach, where architecture and workflow diagrams are versioned, generated, and maintained directly from code alongside infrastructure and application repositories.

## Advantages
- Text-Based (Diagram-as-Code): You write plain text, which means diagrams can be version-controlled with Git, easily compared, and integrated into CI/CD pipelines.
- High Productivity: You don’t waste time dragging and dropping boxes or aligning lines; you focus entirely on the logic and architecture.
- Great Modularity: Thanks to the !include directive, you can break down large diagrams into smaller, reusable modules and share common styles across files.
- Wide Integration: It works seamlessly with major tools like VS Code, IntelliJ, GitHub, GitLab, Confluence, and Markdown documents.
- Auto-Layout: The engine automatically calculates the layout, which is perfect for rapid prototyping and sequence diagrams.

## Disadvantages

- Limited Layout Control: Because the layout engine handles the positioning, you have very little control over where specific components go.
- The "Spaghetti" Effect: As diagrams grow larger and the number of components and arrows increases, the layout can quickly become messy, cluttered, and hard to read.
- Steep Learning Curve for Complex Tuning: Trying to force a specific layout using hacks (like -right-> or [hidden]) can become frustrating and difficult to maintain.
- Basic Aesthetics: By default, the diagrams can look a bit dated unless you spend time configuring modern skins, themes, or custom CSS.

## My opinion

In my view, once the tool's limitations are understood, it allows for highly efficient architecture documentation, particularly when deploying recurring design patterns. Furthermore, its seamless integration with platforms like Confluence helps cut down on licensing costs for proprietary software like Visio.

## AG example3
Below is a PlantUML example describing an AG (Availability Group) configuration with replication and DAG. Typically, to avoid the "Spaghetti" Effect, probably the Shared Backup feature should be described in another file.

`Note: Online UML tools often impose strict limits on diagram size and element counts. In this case, you can use Niolesk to handle larger diagrams.`

1

[AAG example](/CBhDS-Site/PlantUML-AAG.txt)

2

[AAG example]({{< relref "PlantUML-AAG.txt" >}})

3

[AAG example](PlantUML-AAG.txt)
