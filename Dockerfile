# Odoo 17 on Docker for Render (Free plan friendly)
FROM odoo:17.0

USER root
COPY entrypoint.render.sh /entrypoint.render.sh
RUN chmod +x /entrypoint.render.sh
USER odoo

# Optional path for extra addons if you add them later
ENV ADDONS_PATH=/mnt/extra-addons

# Odoo default HTTP port; Render will pass $PORT at runtime
EXPOSE 8069

ENTRYPOINT ["/entrypoint.render.sh"]
