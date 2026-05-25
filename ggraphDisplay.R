library(ggraph) # Use ggraph for better styling than base plot.igraph

# 1. Create a layout specifically for trees (Reingold-Tilford)
layout <- layout_reingold_tilford(graph = g, scale = 1.5)

p <- ggraph(g, layout = layout) +
  
  # Plot Edges (Lines connecting nodes)
  geom_edge_link(aes(color = "gray70"), edge_width = 1) +
  
  # Plot Nodes (Circles/Squares)
  geom_node_point(aes(size = ifelse(is_leaf, 4, 2))) +
  
  # Plot Labels (This is where the logic happens)
  geom_node_text(
    aes(label = name_attr), 
    check_overlap = TRUE,
    show.legend = FALSE
  ) + 
  coord_fixed(ratio = 1.5) + 
  theme_void()

# Save to file for user viewing (HTML/PDF)
ggsave("AST_Visualization.png", plot = p, width = 8, height = 8)
